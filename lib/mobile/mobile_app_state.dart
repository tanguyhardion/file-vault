import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/app_settings_service.dart';
import '../services/cloud/cloud_auth.dart';
import '../services/offline/vault_repository.dart';
import '../services/vault_session.dart';

/// App-wide state for the Android app: the account, the unlocked vault, and
/// inactivity locking (same setting as the desktop app).
class MobileAppState extends ChangeNotifier with WidgetsBindingObserver {
  final CloudAuth auth;
  final VaultRepository repository;

  MobileAppState({required this.auth, required this.repository});

  VaultSession? _session;
  int _lockMinutes = AppSettingsService.defaultInactivityLockMinutes;
  Timer? _inactivityTimer;
  DateTime? _backgroundedAt;

  /// Called before locking so an open editor can save its pending changes.
  Future<void> Function()? beforeLock;

  VaultSession? get session => _session;
  int get lockMinutes => _lockMinutes;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _lockMinutes = await AppSettingsService.getInactivityLockMinutes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _session?.lock();
    super.dispose();
  }

  void startSession(VaultSession session) {
    _session?.lock();
    _session = session;
    userActivity();
    notifyListeners();
  }

  Future<void> lock() async {
    final session = _session;
    if (session == null) return;
    _inactivityTimer?.cancel();
    try {
      await beforeLock?.call();
    } catch (_) {
      // Locking must not be blocked by a failed save.
    }
    if (_session != session) return; // Locked or replaced while saving.
    // Clear first: locking pops the vault screens, which call lock() again.
    _session = null;
    session.lock();
    notifyListeners();
  }

  Future<void> setLockMinutes(int minutes) async {
    await AppSettingsService.setInactivityLockMinutes(minutes);
    _lockMinutes = await AppSettingsService.getInactivityLockMinutes();
    userActivity();
    notifyListeners();
  }

  /// Restarts the inactivity countdown.
  void userActivity() {
    _inactivityTimer?.cancel();
    if (_session == null || _lockMinutes <= 0) return;
    _inactivityTimer = Timer(Duration(minutes: _lockMinutes), lock);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Timers don't run reliably in the background; check on resume.
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        // Pick up changes made on other devices, or send pending ones.
        unawaited(repository.syncAll());
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null &&
            _lockMinutes > 0 &&
            DateTime.now().difference(since) >=
                Duration(minutes: _lockMinutes)) {
          lock();
        } else {
          userActivity();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
