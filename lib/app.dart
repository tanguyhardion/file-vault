import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'mobile/app_lock.dart';
import 'mobile/mobile_root.dart';
import 'screens/sign_in_screen.dart';
import 'screens/vault_home_page.dart';
import 'services/cloud/cloud_auth.dart';
import 'services/cloud/cloud_client.dart';
import 'services/cloud/cloud_config.dart';
import 'services/cloud/cloud_vaults.dart';
import 'services/offline/local_vault_store.dart';
import 'services/offline/vault_repository.dart';
import 'theme/app_theme.dart';
import 'theme/appearance.dart';
import 'widgets/expressive/loading_indicator.dart';

class FileVaultApp extends StatefulWidget {
  final AppearanceController appearance;

  const FileVaultApp({super.key, required this.appearance});

  @override
  State<FileVaultApp> createState() => _FileVaultAppState();
}

class _FileVaultAppState extends State<FileVaultApp> {
  final CloudAuth _auth = CloudAuth(
    baseUrl: CloudConfig.url,
    apiKey: CloudConfig.publishableKey,
  );
  late final CloudVaultRepository _remote = CloudVaultRepository(
    CloudClient(_auth),
  );

  @override
  void initState() {
    super.initState();
    if (CloudConfig.isConfigured) _auth.init();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Appearance(
      controller: widget.appearance,
      child: ValueListenableBuilder(
        valueListenable: widget.appearance,
        builder: (context, accent, _) => MaterialApp(
          title: 'File Vault',
          theme: AppTheme.light(accent),
          darkTheme: AppTheme.dark(accent),
          // The phone's screen lock is required to open the app.
          builder: Platform.isAndroid
              ? (context, child) => AppLockGate(child: child!)
              : null,
          home: CloudConfig.isConfigured
              ? ListenableBuilder(listenable: _auth, builder: (_, _) => _home())
              : const _NotConfiguredScreen(),
        ),
      ),
    );
  }

  Widget _home() {
    if (!_auth.initialized) {
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }
    if (!_auth.isSignedIn) return SignInScreen(auth: _auth);
    // Keyed by account so signing out drops all vault state.
    return _AccountScope(
      key: ValueKey(_auth.email),
      auth: _auth,
      remote: _remote,
    );
  }
}

/// The signed-in account's vaults, kept offline on this device, for as long
/// as the account stays signed in.
class _AccountScope extends StatefulWidget {
  final CloudAuth auth;
  final CloudVaultRepository remote;

  const _AccountScope({super.key, required this.auth, required this.remote});

  @override
  State<_AccountScope> createState() => _AccountScopeState();
}

class _AccountScopeState extends State<_AccountScope> {
  late final VaultRepository _repository = VaultRepository(
    remote: widget.remote,
    store: LocalVaultStore.forAccount(
      getApplicationSupportDirectory,
      widget.auth.email ?? 'account',
    ),
  )..start();

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Platform.isAndroid
        ? MobileRoot(auth: widget.auth, repository: _repository)
        : VaultHomePage(auth: widget.auth, repository: _repository);
  }
}

class _NotConfiguredScreen extends StatelessWidget {
  const _NotConfiguredScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'This build has no database configured. Build with '
            '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
