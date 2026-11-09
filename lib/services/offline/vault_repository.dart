import 'dart:async';

import '../cloud/cloud_auth.dart';
import '../cloud/cloud_client.dart';
import '../cloud/cloud_vaults.dart';
import '../vault_marker.dart';
import 'local_vault_store.dart';
import 'offline_vault_storage.dart';
import 'sync_status.dart';

/// The signed-in account's vaults, available offline.
///
/// Every vault is kept on this device (ciphertext only) and synced in the
/// background: at start, every [_tick] while offline or with unsent changes,
/// shortly after a change, and every [_refreshEvery] otherwise. Creating,
/// importing and deleting vaults needs a connection; file changes don't.
class VaultRepository {
  final CloudVaultRepository remote;
  final LocalVaultStore store;
  final SyncStatus status = SyncStatus();

  final Map<String, OfflineVaultStorage> _storages = {};
  Timer? _ticker;
  Timer? _pushSoon;
  Future<void>? _syncing;
  DateTime? _lastFullSync;
  bool _disposed = false;

  static const _tick = Duration(seconds: 30);
  static const _refreshEvery = Duration(minutes: 5);

  VaultRepository({required this.remote, required this.store});

  /// Starts background syncing.
  void start() {
    _ticker ??= Timer.periodic(_tick, (_) => _onTick());
    unawaited(syncAll());
  }

  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _pushSoon?.cancel();
    status.dispose();
  }

  OfflineVaultStorage storageFor(CloudVault vault) => _storages.putIfAbsent(
    vault.id,
    () => OfflineVaultStorage(
      remote.storageFor(vault),
      store,
      status,
      ({required localWrite}) => _onStorageChanged(vault.id, localWrite),
    ),
  );

  /// The server copy only, for uploads that must not be left half done
  /// offline (importing a vault).
  CloudVaultStorage remoteStorageFor(CloudVault vault) =>
      remote.storageFor(vault);

  /// The account's vaults: from the server, or the copy on this device when
  /// offline. Throws [CloudOfflineException] offline if there is no copy yet.
  Future<List<CloudVault>> list() async {
    final List<CloudVault> vaults;
    try {
      vaults = await remote.list();
    } on CloudOfflineException {
      status.markOffline();
      final rows = await store.readVaults();
      if (rows == null) rethrow;
      return rows.map(CloudVault.fromRow).toList();
    }
    status.markOnline();
    await store.writeVaults([for (final v in vaults) v.toRow()]);
    // Vaults deleted on another device.
    final ids = {for (final v in vaults) v.id};
    for (final id in await store.storedVaultIds()) {
      if (!ids.contains(id)) {
        _storages.remove(id);
        await store.deleteVault(id);
      }
    }
    _recount();
    return vaults;
  }

  Future<CloudVault> create(String name, String password) async =>
      _remember(await remote.create(name, password));

  Future<CloudVault> createWithMarker(
    String name,
    VaultMarker marker, {
    bool autoBackupEnabled = false,
  }) async => _remember(
    await remote.createWithMarker(
      name,
      marker,
      autoBackupEnabled: autoBackupEnabled,
    ),
  );

  Future<CloudVault> setAutoBackupEnabled(
    CloudVault vault,
    bool enabled,
  ) async => _remember(await remote.setAutoBackupEnabled(vault, enabled));

  Future<void> delete(CloudVault vault) async {
    await remote.delete(vault);
    final rows = await store.readVaults() ?? [];
    await store.writeVaults(rows.where((r) => r['id'] != vault.id).toList());
    _storages.remove(vault.id);
    await store.deleteVault(vault.id);
    _recount();
  }

  /// Sends every vault's local changes and downloads what changed elsewhere.
  /// Never throws; the outcome is in [status].
  Future<void> syncAll() =>
      _syncing ??= _syncAll().whenComplete(() => _syncing = null);

  Future<void> _syncAll() async {
    if (_disposed) return;
    status.setSyncing(true);
    try {
      final vaults = await list();
      if (!status.online) return;
      for (final vault in vaults) {
        await storageFor(vault).sync();
      }
      _lastFullSync = DateTime.now();
      if (status.pendingChanges == 0) status.syncSucceeded();
    } on CloudOfflineException {
      status.markOffline();
    } on NotSignedInException {
      // The app returns to the sign-in screen.
    } catch (e) {
      status.reportError(e);
    } finally {
      if (!_disposed) {
        _recount();
        status.setSyncing(false);
      }
    }
  }

  /// Syncs, then returns how many changes still couldn't be sent.
  Future<int> syncBeforeSignOut() async {
    await syncAll();
    return status.pendingChanges;
  }

  /// Removes this account's offline copy (on sign-out).
  Future<void> deleteLocalCopy() async {
    _storages.clear();
    await store.wipe();
  }

  void _onTick() {
    if (_disposed || _syncing != null) return;
    final last = _lastFullSync;
    if (!status.online ||
        status.pendingChanges > 0 ||
        last == null ||
        DateTime.now().difference(last) >= _refreshEvery) {
      unawaited(syncAll());
    }
  }

  void _onStorageChanged(String vaultId, bool localWrite) {
    if (_disposed) return;
    _recount();
    if (!localWrite) return;
    // Send it shortly, batching quick successive saves.
    _pushSoon?.cancel();
    _pushSoon = Timer(const Duration(seconds: 2), () async {
      final storage = _storages[vaultId];
      if (storage == null || _disposed) return;
      try {
        await storage.sync();
      } on CloudOfflineException {
        status.markOffline();
      } on NotSignedInException {
        // The app returns to the sign-in screen.
      } catch (e) {
        status.reportError(e);
      }
    });
  }

  void _recount() {
    if (_disposed) return;
    status.setPendingChanges(
      _storages.values.fold(0, (sum, s) => sum + s.pendingChanges),
    );
  }

  /// Keeps [vault] in the offline vault list.
  Future<CloudVault> _remember(CloudVault vault) async {
    final rows = await store.readVaults() ?? [];
    final i = rows.indexWhere((r) => r['id'] == vault.id);
    if (i >= 0) {
      rows[i] = vault.toRow();
    } else {
      rows
        ..add(vault.toRow())
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    }
    await store.writeVaults(rows);
    return vault;
  }
}
