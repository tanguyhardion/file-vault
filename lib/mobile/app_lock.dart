import 'package:material_ui/material_ui.dart';

import '../widgets/expressive/shaped_icon.dart';
import 'device_auth.dart';

/// Keeps the whole app (sign-in, vault list, open vaults and dialogs) behind
/// the phone's screen lock: on launch, and when coming back after
/// [relockAfter] in the background.
///
/// Placed above the [Navigator] (in [MaterialApp.builder]) so pushed screens
/// are covered too. The app below keeps its state while locked.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  /// Short app switches (e.g. copying a code from another app) don't lock.
  static const relockAfter = Duration(seconds: 30);

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = true;
  bool _authenticating = false;
  String? _error;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // A screen lock prompt (ours or a vault's) can pause the app.
        if (!_locked && !DeviceAuth.inProgress) {
          _backgroundedAt ??= DateTime.now();
        }
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null &&
            DateTime.now().difference(since) >= AppLockGate.relockAfter) {
          setState(() {
            _locked = true;
            _error = null;
          });
          _unlock();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !_locked || !mounted) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    String? error;
    var unlocked = false;
    try {
      await DeviceAuth.require(reason: 'Unlock File Vault');
      unlocked = true;
    } on DeviceAuthCancelledException {
      // Stay locked; the user can try again.
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _locked = !unlocked;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: _locked,
          child: TickerMode(
            enabled: !_locked,
            child: Offstage(offstage: _locked, child: widget.child),
          ),
        ),
        if (_locked)
          _LockScreen(
            authenticating: _authenticating,
            error: _error,
            onUnlock: _unlock,
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  final bool authenticating;
  final String? error;
  final VoidCallback onUnlock;

  const _LockScreen({
    required this.authenticating,
    required this.error,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ShapedIcon(Icons.lock_outline),
                const SizedBox(height: 24),
                Text('File Vault is locked', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  error ?? 'Use your screen lock to continue.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: error == null ? null : theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: authenticating ? null : onUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
