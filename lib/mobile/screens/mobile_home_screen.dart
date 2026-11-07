import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';
import '../device_auth.dart';
import '../mobile_app_state.dart';
import '../onedrive/onedrive_config.dart';
import '../saved_vaults_store.dart';
import '../storage/local_vault_storage.dart';
import '../storage/onedrive_vault_storage.dart';
import '../storage/vault_storage.dart';
import '../storage_access.dart';
import '../vault_session.dart';
import 'local_folder_picker_screen.dart';
import 'onedrive_folder_picker_screen.dart';
import 'vault_files_screen.dart';

class MobileHomeScreen extends StatefulWidget {
  final MobileAppState appState;

  const MobileHomeScreen({super.key, required this.appState});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  List<SavedVault> _vaults = [];
  bool _initializing = true;
  bool _busy = false;

  MobileAppState get _app => widget.appState;

  @override
  void initState() {
    super.initState();
    _app.auth.addListener(_onChanged);
    _init();
  }

  @override
  void dispose() {
    _app.auth.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    await _app.init();
    await _loadVaults();
    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _loadVaults() async {
    final vaults = await SavedVaultsStore.getAll();
    if (mounted) setState(() => _vaults = vaults);
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

  /// Signs in to OneDrive if needed; returns whether the user is signed in.
  Future<bool> _ensureSignedIn() async {
    if (_app.auth.isSignedIn) return true;
    setState(() => _busy = true);
    try {
      return await _app.auth.signIn();
    } catch (e) {
      _showError(e);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _ensureStorageAccess() async {
    if (await StorageAccess.ensure()) return true;
    if (mounted) {
      await showErrorDialog(
        context,
        title: 'Storage Access Needed',
        message:
            'Allow "All files access" for File Vault so it can read and write '
            'vault folders on this phone.',
      );
    }
    return false;
  }

  Future<void> _addVault() async {
    var location = VaultLocation.local;
    if (OneDriveConfig.isConfigured) {
      final picked = await showModalBottomSheet<VaultLocation>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: const Text('Folder on this phone'),
                onTap: () => Navigator.pop(ctx, VaultLocation.local),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('OneDrive'),
                onTap: () => Navigator.pop(ctx, VaultLocation.oneDrive),
              ),
            ],
          ),
        ),
      );
      if (picked == null) return;
      location = picked;
    }
    if (!mounted) return;

    SavedVault? vault;
    switch (location) {
      case VaultLocation.local:
        if (!await _ensureStorageAccess()) return;
        final root = await StorageAccess.storageRoot;
        if (!mounted) return;
        vault = await Navigator.of(context).push<SavedVault>(
          MaterialPageRoute(
            builder: (_) => LocalFolderPickerScreen(rootPath: root),
          ),
        );
      case VaultLocation.oneDrive:
        if (!await _ensureSignedIn() || !mounted) return;
        vault = await Navigator.of(context).push<SavedVault>(
          MaterialPageRoute(
            builder: (_) => OneDriveFolderPickerScreen(client: _app.client),
          ),
        );
    }
    if (vault == null) return;
    await SavedVaultsStore.add(vault);
    await _loadVaults();
    if (mounted) await _openVault(vault);
  }

  Future<void> _removeVault(SavedVault vault) async {
    await SavedVaultsStore.remove(vault);
    await _loadVaults();
  }

  /// Storage for [vault], after making sure it can be accessed.
  Future<VaultStorage?> _storageFor(SavedVault vault) async {
    switch (vault.location) {
      case VaultLocation.local:
        if (!await _ensureStorageAccess()) return null;
        return LocalVaultStorage(vault.id);
      case VaultLocation.oneDrive:
        if (!OneDriveConfig.isConfigured) {
          _showError('This build has no OneDrive client ID.');
          return null;
        }
        if (!await _ensureSignedIn()) return null;
        return OneDriveVaultStorage(_app.client, vault.id);
    }
  }

  Future<void> _openVault(SavedVault vault) async {
    final storage = await _storageFor(vault);
    if (storage == null) return;

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
        session = await VaultSession.unlock(storage, vault, password);
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
      if (error is VaultFolderMissingException) {
        await showErrorDialog(
          context,
          title: 'Vault Not Found',
          message:
              'This vault folder no longer exists. It will be removed from '
              'the list.',
        );
        await _removeVault(vault);
        return;
      }
      if (error != null) {
        _showError(error);
        return;
      }

      await SavedVaultsStore.add(vault);
      await _loadVaults();
      _app.startSession(session!);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VaultFilesScreen(appState: _app, session: session!),
        ),
      );
      return;
    }
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
          if (_app.auth.isSignedIn)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'signout') _signOut();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'signout',
                  child: Text('Sign out of OneDrive'),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: _initializing
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _addVault,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Add vault'),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_vaults.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.lock_outline,
        title: 'No vaults yet',
        message:
            'Tap "Add vault" and pick a vault folder on this phone, for '
            'example one kept in sync with your PC by Syncthing. Files are '
            'decrypted only in memory.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _vaults.length,
      itemBuilder: (context, i) {
        final vault = _vaults[i];
        return ListTile(
          leading: Icon(
            vault.location == VaultLocation.oneDrive
                ? Icons.cloud_outlined
                : Icons.lock_outline,
          ),
          title: Text(vault.name),
          subtitle: Text(vault.path, overflow: TextOverflow.ellipsis),
          onTap: _busy ? null : () => _openVault(vault),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'remove') _removeVault(vault);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remove', child: Text('Remove from list')),
            ],
          ),
        );
      },
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
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
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
