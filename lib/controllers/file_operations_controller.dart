import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vault_models.dart';
import '../services/vault_service.dart';
import '../services/crypto_service.dart';
import '../services/crypto_worker.dart';
import '../services/content_cache.dart';
import 'vault_controller.dart';

class FileOperationsController extends ChangeNotifier {
  final VaultController _vaultController;
  DecryptedFileContent? _openedContent;
  bool _dirty = false;
  bool _loading = false;

  FileOperationsController(this._vaultController);

  DecryptedFileContent? get openedContent => _openedContent;
  bool get dirty => _dirty;
  bool get loading => _loading;

  void setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }

  void setDirty(bool dirty) {
    _dirty = dirty;
    notifyListeners();
  }

  Future<void> openFile(VaultFileEntry file) async {
    final password = _vaultController.vaultPassword;
    if (password == null) return;

    setLoading(true);
    try {
      // Check cache before reading/decrypting
      final fp = await VaultService.getFingerprint(file.fullPath);
      final cached = ContentCache.instance.getIfFresh(file.fullPath, fp);
      if (cached != null) {
        _openedContent = DecryptedFileContent(content: cached, source: file);
        _dirty = false;
        setLoading(false);
        return;
      }

      final bytes = await VaultService.readVaultFileBytes(file.fullPath);
      String text;
      if (bytes.isEmpty) {
        text = '';
      } else {
        // Offload decryption to a background isolate for responsiveness
        text = await CryptoWorker.decryptToString(
          data: bytes,
          password: password,
        );
      }

      _openedContent = DecryptedFileContent(content: text, source: file);
      _dirty = false;
      setLoading(false);

      // Update cache
      final fp2 = await VaultService.getFingerprint(file.fullPath);
      ContentCache.instance.put(file.fullPath, text, fp2);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  Future<VaultFileEntry> createNewFile(String name) async {
    final vaultDir = _vaultController.vaultDir;
    final password = _vaultController.vaultPassword;

    if (vaultDir == null || password == null) {
      throw Exception('No vault is open');
    }

    setLoading(true);
    try {
      // Create file with empty content
      final Uint8List encrypted = await CryptoService.encryptString(
        content: '',
        password: password,
      );

      final entry = await VaultService.writeVaultFileBytes(
        dirPath: vaultDir,
        fileNameWithoutExt: name,
        encryptedBytes: encrypted,
      );

      await _vaultController.refreshFiles();

      _openedContent = DecryptedFileContent(content: '', source: entry);
      _dirty = false;
      setLoading(false);

      return entry;
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  Future<void> saveCurrentFile(String content) async {
    final current = _openedContent;
    final password = _vaultController.vaultPassword;
    if (current == null || password == null) return;

    setLoading(true);
    try {
      // Offload encryption to background isolate
      final encrypted = await CryptoWorker.encryptString(
        content: content,
        password: password,
      );

      await VaultService.overwriteVaultFileBytes(
        fullPath: current.source.fullPath,
        encryptedBytes: encrypted,
      );

      _openedContent = DecryptedFileContent(
        content: content,
        source: current.source,
      );
      _dirty = false;
      setLoading(false);

      // Refresh cache with new fingerprint
      final fp = await VaultService.getFingerprint(current.source.fullPath);
      ContentCache.instance.put(current.source.fullPath, content, fp);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  Future<VaultFileEntry> renameFile(VaultFileEntry file, String newName) async {
    final vaultDir = _vaultController.vaultDir;
    if (vaultDir == null) throw Exception('No vault is open');

    setLoading(true);
    try {
      final updated = await VaultService.renameVaultFile(
        fullPath: file.fullPath,
        newFileNameWithoutExt: newName,
      );

      await _vaultController.refreshFiles();

      // If currently open, update source path and title
      if (_openedContent?.source.fullPath == file.fullPath) {
        _openedContent = DecryptedFileContent(
          content: _openedContent!.content,
          source: updated,
        );
      }

      setLoading(false);
      return updated;
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  Future<void> deleteFile(VaultFileEntry file) async {
    final vaultDir = _vaultController.vaultDir;
    if (vaultDir == null) throw Exception('No vault is open');

    setLoading(true);
    try {
      await VaultService.deleteVaultFile(file.fullPath);
      await _vaultController.refreshFiles();

      if (_openedContent?.source.fullPath == file.fullPath) {
        _openedContent = null;
        _dirty = false;
      }

      setLoading(false);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  void closeFile() {
    _openedContent = null;
    _dirty = false;
    notifyListeners();
  }
}
