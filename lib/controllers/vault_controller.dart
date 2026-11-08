import 'package:material_ui/material_ui.dart';

import '../services/cloud/cloud_vaults.dart';
import '../services/storage/vault_storage.dart';
import '../services/vault_session.dart';

/// The account's vaults and the currently unlocked one (desktop).
class VaultController extends ChangeNotifier {
  final CloudVaultRepository repository;

  List<CloudVault> _vaults = [];
  VaultSession? _session;
  bool _loading = false;

  VaultController(this.repository);

  List<CloudVault> get vaults => _vaults;
  VaultSession? get session => _session;
  CloudVault? get vault => _session?.vault;
  List<VaultItem> get files => _session?.files ?? const [];
  bool get loading => _loading;
  bool get isVaultOpen => _session != null && !_session!.isLocked;

  void setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }

  Future<void> loadVaults() async {
    _vaults = await repository.list();
    notifyListeners();
  }

  /// Throws [WrongPasswordException] if [password] is wrong.
  Future<void> unlock(CloudVault vault, String password) async {
    final session = await VaultSession.unlock(
      repository.storageFor(vault),
      vault,
      password,
    );
    _setSession(session);
  }

  /// Opens a session for a vault that was just created or imported with
  /// [password] (already known to be right).
  void openSession(VaultSession session) => _setSession(session);

  Future<CloudVault> createVault(String name, String password) async {
    final vault = await repository.create(name, password);
    _setSession(
      VaultSession(repository.storageFor(vault), vault, password, []),
    );
    await loadVaults();
    return vault;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final session = _session;
    if (session == null) return;
    final updated = await repository.setAutoBackupEnabled(
      session.vault,
      enabled,
    );
    session.updateVault(updated);
    _vaults = [for (final v in _vaults) v.id == updated.id ? updated : v];
    notifyListeners();
  }

  void closeVault() {
    final session = _session;
    _session = null;
    session?.removeListener(notifyListeners);
    session?.lock();
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshFiles() async {
    await _session?.refresh();
  }

  void _setSession(VaultSession session) {
    final old = _session;
    old?.removeListener(notifyListeners);
    old?.lock();
    _session = session..addListener(notifyListeners);
    notifyListeners();
  }

  @override
  void dispose() {
    closeVault();
    super.dispose();
  }
}
