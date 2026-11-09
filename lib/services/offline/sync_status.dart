import 'package:flutter/foundation.dart';

/// Connection and sync state, shown in the app bars.
class SyncStatus extends ChangeNotifier {
  bool _online = true;
  bool _syncing = false;
  int _pendingChanges = 0;
  Object? _error;
  DateTime? _lastSyncedAt;

  /// False after a request failed for lack of a connection, until one works.
  bool get online => _online;
  bool get syncing => _syncing;

  /// Files changed on this device that the server doesn't have yet.
  int get pendingChanges => _pendingChanges;

  /// Why the last sync failed, other than being offline.
  Object? get error => _error;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  void markOnline() => _set(() => _online = true);
  void markOffline() => _set(() => _online = false);
  void setSyncing(bool value) => _set(() => _syncing = value);
  void setPendingChanges(int value) => _set(() => _pendingChanges = value);
  void reportError(Object error) => _set(() => _error = error);

  void syncSucceeded() => _set(() {
    _online = true;
    _error = null;
    _lastSyncedAt = DateTime.now();
  });

  void _set(VoidCallback change) {
    final before = (_online, _syncing, _pendingChanges, _error, _lastSyncedAt);
    change();
    if (before != (_online, _syncing, _pendingChanges, _error, _lastSyncedAt)) {
      notifyListeners();
    }
  }
}
