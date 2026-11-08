import 'package:material_ui/material_ui.dart';

import '../../services/cloud/cloud_vaults.dart';
import '../../services/vault_session.dart';
import '../../widgets/widgets.dart';
import '../device_auth.dart';
import '../mobile_app_state.dart';
import 'vault_files_screen.dart';

class MobileHomeScreen extends StatefulWidget {
  final MobileAppState appState;

  const MobileHomeScreen({super.key, required this.appState});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  List<CloudVault> _vaults = [];
  bool _initializing = true;
  Object? _loadError;

  MobileAppState get _app => widget.appState;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _app.init();
    await _loadVaults();
    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _loadVaults() async {
    try {
      final vaults = await _app.repository.list();
      if (mounted) {
        setState(() {
          _vaults = vaults;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future<void> _signOut() async {
    await _app.lock();
    await _app.auth.signOut();
  }

  Future<void> _createVault() async {
    final name = await promptForName(
      context,
      title: 'New vault',
      label: 'Vault name',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final password = await promptForPasswordCreation(
      context,
      title: 'Set a password for this vault',
    );
    if (password == null || password.isEmpty || !mounted) return;

    showLoadingDialog(context, message: 'Creating vault...');
    CloudVault? vault;
    Object? error;
    try {
      vault = await _app.repository.create(name.trim(), password);
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // loading dialog
    if (error != null) {
      _showError(error);
      return;
    }
    await _loadVaults();
    final session = VaultSession(
      _app.repository.storageFor(vault!),
      vault,
      password,
      [],
    );
    await _enter(session);
  }

  Future<void> _openVault(CloudVault vault) async {
    while (true) {
      if (!mounted) return;
      final password = await promptForPasswordWithVerification(
        context,
        title: '${vault.name} password',
      );
      if (password == null || !mounted) return;

      // Every password attempt, right or wrong, must pass the phone's screen
      // lock first, so passwords can't be tried on this phone without it.
      try {
        await DeviceAuth.require(
          reason: 'Confirm it\'s you to open ${vault.name}',
        );
      } on DeviceAuthCancelledException {
        return;
      } catch (e) {
        if (mounted) {
          await showErrorDialog(
            context,
            title: 'Screen Lock Required',
            message: e.toString(),
          );
        }
        return;
      }
      if (!mounted) return;

      showLoadingDialog(context, message: 'Unlocking vault...');
      VaultSession? session;
      Object? error;
      try {
        session = await VaultSession.unlock(
          _app.repository.storageFor(vault),
          vault,
          password,
        );
      } catch (e) {
        error = e;
      }
      if (!mounted) return;
      Navigator.of(context).pop(); // loading dialog

      if (error is WrongPasswordException) {
        await showErrorDialog(
          context,
          title: 'Incorrect Password',
          message: 'The password you entered is incorrect. Please try again.',
        );
        continue;
      }
      if (error != null) {
        _showError(error);
        return;
      }
      await _enter(session!);
      return;
    }
  }

  Future<void> _enter(VaultSession session) async {
    _app.startSession(session);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VaultFilesScreen(appState: _app, session: session),
      ),
    );
  }

  Future<void> _showSettings() async {
    final minutes = await showAppSettingsDialog(
      context,
      currentMinutes: _app.lockMinutes,
    );
    if (minutes != null) await _app.setLockMinutes(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Vault'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettings,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'signout') _signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(_app.auth.email ?? 'Signed in'),
              ),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      floatingActionButton: _initializing
          ? null
          : FloatingActionButton.extended(
              onPressed: _createVault,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('New vault'),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: LoadingIndicator());
    }
    final Widget content;
    if (_loadError != null && _vaults.isEmpty) {
      content = _CenteredMessage(
        icon: Icons.cloud_off,
        title: 'Could not load vaults',
        message: '$_loadError\n\nPull down to try again.',
      );
    } else if (_vaults.isEmpty) {
      content = const _CenteredMessage(
        icon: Icons.lock_outline,
        title: 'No vaults yet',
        message:
            'Tap "New vault", or import an existing vault folder from the '
            'desktop app. Vaults sync between your devices; files are only '
            'decrypted in memory on this phone.',
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: _vaults.length,
        itemBuilder: (context, i) {
          final vault = _vaults[i];
          return ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(vault.name),
            onTap: () => _openVault(vault),
          );
        },
      );
    }
    return RefreshIndicator(
      onRefresh: _loadVaults,
      child: content is ListView
          ? content
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(height: constraints.maxHeight, child: content),
              ),
            ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShapedIcon(icon),
            const SizedBox(height: 24),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
