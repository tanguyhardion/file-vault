import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'mobile/mobile_root.dart';
import 'screens/sign_in_screen.dart';
import 'screens/vault_home_page.dart';
import 'services/cloud/cloud_auth.dart';
import 'services/cloud/cloud_client.dart';
import 'services/cloud/cloud_config.dart';
import 'services/cloud/cloud_vaults.dart';

class FileVaultApp extends StatefulWidget {
  const FileVaultApp({super.key});

  @override
  State<FileVaultApp> createState() => _FileVaultAppState();
}

class _FileVaultAppState extends State<FileVaultApp> {
  final CloudAuth _auth = CloudAuth(
    baseUrl: CloudConfig.url,
    apiKey: CloudConfig.publishableKey,
  );
  late final CloudVaultRepository _repository = CloudVaultRepository(
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
    return MaterialApp(
      title: 'File Vault',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: CloudConfig.isConfigured
          ? ListenableBuilder(listenable: _auth, builder: (_, _) => _home())
          : const _NotConfiguredScreen(),
    );
  }

  Widget _home() {
    if (!_auth.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_auth.isSignedIn) return SignInScreen(auth: _auth);
    // Keyed by account so signing out drops all vault state.
    final key = ValueKey(_auth.email);
    return Platform.isAndroid
        ? MobileRoot(key: key, auth: _auth, repository: _repository)
        : VaultHomePage(key: key, auth: _auth, repository: _repository);
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
