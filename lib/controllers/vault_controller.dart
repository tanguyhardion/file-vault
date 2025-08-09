
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/vault_models.dart';
import '../services/vault_service.dart';
import '../services/recent_vaults_service.dart';

class VaultController extends ChangeNotifier {
  // Allows creating only the marker file, without setting password or files
  Future<void> createVaultMarkerOnly(String dir) async {
    await _createVaultMarker(dir);
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
    return contents.contains('password_set: true');
  }

  Future<bool> _checkVaultMarker(String dir) async {
    return checkVaultMarker(dir);
  }

  Future<void> _createVaultMarker(String dir) async {
    final marker = File('$dir/$vaultMarkerFile');
    final now = DateTime.now().toUtc().toIso8601String();
    final contents = 'vault_version: 1\ncreated_at: $now\npassword_set: true\n';
    await marker.writeAsString(contents, flush: true);
  }

  Future<void> openVault(String dir, String password) async {
    setLoading(true);
    try {
      // Check marker file
      final hasMarker = await _checkVaultMarker(dir);
      if (!hasMarker) {
        throw Exception('Selected folder is not a valid vault (missing marker file).');
      }
      _vaultDir = dir;
      _vaultPassword = password;

      final files = await VaultService.listVaultFiles(dir);
      _files = files;

      // Store to recent list
      await RecentVaultsService.add(dir);

      setLoading(false);
    } catch (e) {
      _vaultDir = null;
      _vaultPassword = null;
      _files = [];
      setLoading(false);
      rethrow;
    }
  }

  Future<void> createVault(String dir, String password) async {
    _vaultDir = dir;
    _vaultPassword = password;
    _files = [];
    await _createVaultMarker(dir);
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
