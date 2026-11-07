import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../services/crypto_worker.dart';
import '../services/vault_marker.dart';
import '../services/vault_service.dart';
import 'saved_vaults_store.dart';
import 'storage/vault_storage.dart';

class WrongPasswordException implements Exception {
  @override
  String toString() => 'Incorrect password.';
}

class NotAVaultException implements Exception {
  @override
  String toString() => 'This folder is not a vault (missing .vault_marker).';
}

/// A decrypted file held in memory, plus the version it was read from.
class OpenedVaultFile {
  final VaultItem item;
  final String content;

  const OpenedVaultFile({required this.item, required this.content});
}

/// An unlocked vault.
///
/// Encryption and decryption happen here, in memory. Only ciphertext is passed
/// to the [VaultStorage], and plaintext is never written anywhere.
class VaultSession extends ChangeNotifier {
  final VaultStorage _storage;
  final SavedVault vault;
  String? _password;
  List<VaultItem> _files;

  VaultSession._(this._storage, this.vault, this._password, this._files);

  List<VaultItem> get files => _files;
  bool get isLocked => _password == null;

  /// Verifies [password] against the vault marker and lists the files.
  static Future<VaultSession> unlock(
    VaultStorage storage,
    SavedVault vault,
    String password,
  ) async {
    final items = await storage.listFiles();
    final markerItem = items.where((c) => c.name == VaultMarker.fileName);
    if (markerItem.isEmpty) throw NotAVaultException();

    final markerBytes = await storage.read(markerItem.first);
    final marker = VaultMarker.tryParse(utf8.decode(markerBytes));
    if (marker == null) throw NotAVaultException();
    // PBKDF2 is slow on phones; keep it off the UI isolate.
    final ok = await Isolate.run(() => marker.verifyPassword(password));
    if (!ok) throw WrongPasswordException();

    return VaultSession._(storage, vault, password, _vaultFiles(items));
  }

  Future<void> refresh() async {
    _files = _vaultFiles(await _storage.listFiles());
    notifyListeners();
  }

  /// Always reads the latest version from storage.
  Future<OpenedVaultFile> openFile(VaultItem file) async {
    final password = _requirePassword();
    // Metadata first: if the file changes between these two calls, the older
    // version makes the next save fail with a conflict instead of losing data.
    final item = await _storage.stat(file);
    final bytes = await _storage.read(item);
    final content = bytes.isEmpty
        ? ''
        : await CryptoWorker.decryptToString(data: bytes, password: password);
    _replaceFile(item);
    return OpenedVaultFile(item: item, content: content);
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
    final item = await _storage.create(_fileName(nameWithoutExt), encrypted);
    _files = _sorted([..._files, item]);
    notifyListeners();
    return OpenedVaultFile(item: item, content: '');
  }

  Future<VaultItem> renameFile(VaultItem file, String newNameWithoutExt) async {
    _requirePassword();
    final item = await _storage.rename(file, _fileName(newNameWithoutExt));
    _files = _sorted([..._files.where((f) => f.id != file.id), item]);
    notifyListeners();
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

  static String _fileName(String nameWithoutExt) =>
      '${VaultService.sanitizeFileName(nameWithoutExt)}${VaultService.fvaExtension}';

  static List<VaultItem> _vaultFiles(List<VaultItem> items) => _sorted(
    items
        .where((c) => c.name.toLowerCase().endsWith(VaultService.fvaExtension))
        .toList(),
  );

  static List<VaultItem> _sorted(List<VaultItem> files) =>
      files
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
