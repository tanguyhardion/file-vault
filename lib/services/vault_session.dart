import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'cloud/cloud_vaults.dart';
import 'crypto_worker.dart';
import 'storage/vault_storage.dart';
import 'vault_service.dart';

class WrongPasswordException implements Exception {
  @override
  String toString() => 'Incorrect password.';
}

/// A decrypted file held in memory, plus the version it was read from.
class OpenedVaultFile {
  final VaultItem item;
  final String content;

  const OpenedVaultFile({required this.item, required this.content});
}

/// An unlocked vault, shared by the desktop and Android UIs.
///
/// Encryption and decryption happen here, in memory. Only ciphertext is passed
/// to the [VaultStorage], and plaintext is never written anywhere.
class VaultSession extends ChangeNotifier {
  final VaultStorage _storage;
  CloudVault _vault;
  String? _password;
  List<VaultItem> _files;

  VaultSession(this._storage, this._vault, this._password, this._files);

  CloudVault get vault => _vault;
  List<VaultItem> get files => _files;
  bool get isLocked => _password == null;
  VaultStorage get storage => _storage;

  /// Verifies [password] against the vault marker and lists the files.
  static Future<VaultSession> unlock(
    VaultStorage storage,
    CloudVault vault,
    String password,
  ) async {
    final marker = vault.marker;
    // PBKDF2 is slow on phones; keep it off the UI isolate.
    final ok = await Isolate.run(() => marker.verifyPassword(password));
    if (!ok) throw WrongPasswordException();
    final items = await storage.listFiles();
    return VaultSession(storage, vault, password, _vaultFiles(items));
  }

  void updateVault(CloudVault vault) {
    _vault = vault;
    notifyListeners();
  }

  Future<void> refresh() async {
    _files = _vaultFiles(await _storage.listFiles());
    notifyListeners();
  }

  /// Always reads the latest version from storage.
  Future<OpenedVaultFile> openFile(VaultItem file) async {
    // Metadata first: if the file changes between these two calls, the older
    // version makes the next save fail with a conflict instead of losing data.
    final item = await _storage.stat(file);
    final content = await decrypt(item);
    _replaceFile(item);
    return OpenedVaultFile(item: item, content: content);
  }

  /// Downloads and decrypts [item] as listed, without checking its version.
  Future<String> decrypt(VaultItem item) async {
    final password = _requirePassword();
    final bytes = await _storage.read(item);
    return bytes.isEmpty
        ? ''
        : CryptoWorker.decryptToString(data: bytes, password: password);
  }

  /// Encrypts and writes [content]. Unless [overwrite] is set, fails with
  /// [FileChangedExternallyException] if the file changed since [opened] was
  /// read.
  Future<OpenedVaultFile> save(
    OpenedVaultFile opened,
    String content, {
    bool overwrite = false,
  }) async {
    final password = _requirePassword();
    final encrypted = await CryptoWorker.encryptString(
      content: content,
      password: password,
    );
    final item = await _storage.write(
      opened.item,
      encrypted,
      ifVersion: overwrite ? null : opened.item.version,
    );
    _replaceFile(item);
    return OpenedVaultFile(item: item, content: content);
  }

  Future<OpenedVaultFile> createFile(String nameWithoutExt) async {
    final password = _requirePassword();
    final encrypted = await CryptoWorker.encryptString(
      content: '',
      password: password,
    );
    final item = await _storage.create(
      VaultService.fileNameFor(nameWithoutExt),
      encrypted,
    );
    _files = _sorted([..._files, item]);
    notifyListeners();
    return OpenedVaultFile(item: item, content: '');
  }

  Future<VaultItem> renameFile(VaultItem file, String newNameWithoutExt) async {
    _requirePassword();
    final item = await _storage.rename(
      file,
      VaultService.fileNameFor(newNameWithoutExt),
    );
    _replaceFile(item);
    return item;
  }

  Future<void> deleteFile(VaultItem file) async {
    _requirePassword();
    await _storage.delete(file);
    _files = _files.where((f) => f.id != file.id).toList();
    notifyListeners();
  }

  void lock() {
    if (_password == null) return;
    _password = null;
    _files = [];
    notifyListeners();
  }

  String _requirePassword() {
    final pw = _password;
    if (pw == null) throw StateError('Vault is locked');
    return pw;
  }

  void _replaceFile(VaultItem item) {
    _files = _sorted([..._files.where((f) => f.id != item.id), item]);
    notifyListeners();
  }

  static List<VaultItem> _vaultFiles(List<VaultItem> items) => _sorted(
    items.where((c) => VaultService.isVaultFileName(c.name)).toList(),
  );

  static List<VaultItem> _sorted(List<VaultItem> files) =>
      files
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
