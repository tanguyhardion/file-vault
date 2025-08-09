import 'package:flutter/material.dart';

import '../models/vault_models.dart';
import '../services/vault_service.dart';
import '../services/recent_vaults_service.dart';

class VaultController extends ChangeNotifier {
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

  Future<void> openVault(String dir, String password) async {
    setLoading(true);
    try {
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

  void createVault(String dir, String password) {
    _vaultDir = dir;
    _vaultPassword = password;
    _files = [];
    RecentVaultsService.add(dir);
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
