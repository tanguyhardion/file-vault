import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../models/vault_models.dart';
import '../services/vault_service.dart';
import '../services/recent_vaults_service.dart';
import '../services/crypto_service.dart';

class VaultController extends ChangeNotifier {
  // Allows creating only the marker file, without setting password or files
  Future<void> createVaultMarkerOnly(String dir, {String? password}) async {
    // If password is not provided, use a default (not recommended, but for marker restoration)
    final pw = password ?? '';
    await _createVaultMarker(dir, password: pw);
    await RecentVaultsService.add(dir);
    notifyListeners();
  }
  String? _vaultDir;
  String? _vaultPassword;
  List<VaultFileEntry> _files = [];
  bool _loading = false;

  String? get vaultDir => _vaultDir;
  String? get vaultPassword => _vaultPassword;
  List<VaultFileEntry> get files => _files;
  bool get loading => _loading;
  bool get isVaultOpen => _vaultDir != null && _vaultPassword != null;

  void setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }

  static const String vaultMarkerFile = '.vault_marker';

  Future<bool> checkVaultMarker(String dir) async {
    final marker = File('$dir/$vaultMarkerFile');
    if (!await marker.exists()) return false;
    final contents = await marker.readAsString();
    return contents.contains('password_hash:');
  }

  Future<void> _createVaultMarker(String dir, {required String password}) async {
    final marker = File('$dir/$vaultMarkerFile');
    final now = DateTime.now().toUtc().toIso8601String();
    // Generate salt
    final salt = CryptoService.randomSalt();
    // Hash password
    final hash = await CryptoService.hashPassword(password: password, salt: salt);
    final contents = 'vault_version: 1\ncreated_at: $now\nsalt: ${base64Encode(salt)}\npassword_hash: ${base64Encode(hash)}\n';
    await marker.writeAsString(contents, flush: true);
  }

  Future<void> openVault(String dir, String password) async {
    setLoading(true);
    try {
      // Check marker file
      final hasMarker = await checkVaultMarker(dir);
      if (!hasMarker) {
        throw Exception('Selected folder is not a valid vault (missing marker file).');
      }
      
      // Don't set vault state yet - wait for password verification
      // Just store to recent list for now
      await RecentVaultsService.add(dir);

      setLoading(false);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  /// Sets the vault as open after successful password verification
  void setVaultOpen(String dir, String password, List<VaultFileEntry> files) {
    _vaultDir = dir;
    _vaultPassword = password;
    _files = files;
    notifyListeners();
  }

  /// Verifies a password for a specific vault directory by attempting to decrypt an existing file.
  /// Returns the list of files if password is correct, null if incorrect.
  /// If no files exist, returns empty list (password can't be verified but is assumed correct).
  Future<List<VaultFileEntry>?> verifyPasswordForVault(String vaultDir, String password) async {
    try {
      // Read marker file
      final marker = File('$vaultDir/$vaultMarkerFile');
      if (!await marker.exists()) return null;
      final contents = await marker.readAsString();
      final saltLine = contents.split('\n').firstWhere((l) => l.startsWith('salt: '), orElse: () => '');
      final hashLine = contents.split('\n').firstWhere((l) => l.startsWith('password_hash: '), orElse: () => '');
      if (saltLine.isEmpty || hashLine.isEmpty) return null;
      final salt = base64Decode(saltLine.substring(6).trim());
      final storedHash = base64Decode(hashLine.substring(15).trim());
      final inputHash = await CryptoService.hashPassword(password: password, salt: salt);
      if (!ListEquality().equals(storedHash, inputHash)) {
        return null;
      }
      // Password is correct, return files
      final files = await VaultService.listVaultFiles(vaultDir);
      return files;
    } catch (e) {
      return null;
    }
  }

  Future<void> createVault(String dir, String password) async {
    _vaultDir = dir;
    _vaultPassword = password;
    _files = [];
    await _createVaultMarker(dir, password: password);
    await RecentVaultsService.add(dir);
    notifyListeners();
  }

  void closeVault() {
    _vaultDir = null;
    _vaultPassword = null;
    _files = [];
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshFiles() async {
    if (_vaultDir != null) {
      final files = await VaultService.listVaultFiles(_vaultDir!);
      _files = files;
      notifyListeners();
    }
  }

  void updateFiles(List<VaultFileEntry> files) {
    _files = files;
    notifyListeners();
  }
}
