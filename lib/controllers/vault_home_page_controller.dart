import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../services/app_settings_service.dart';
import '../services/backup_service.dart';
import '../services/cloud/cloud_auth.dart';
import '../services/cloud/cloud_vaults.dart';
import '../services/offline/vault_repository.dart';
import '../services/content_cache.dart';
import '../services/storage/vault_storage.dart';
import '../services/vault_archive.dart';
import '../services/vault_session.dart';
import '../widgets/widgets.dart';
import 'file_operations_controller.dart';
import 'search_controller.dart' as vault_search;
import 'vault_controller.dart';

class VaultHomePageController extends ChangeNotifier {
  final CloudAuth auth;
  final VaultController vaultController;
  late final FileOperationsController fileOperationsController;
  late final vault_search.SearchController searchController;

  final TextEditingController editorController = TextEditingController();
  int? _hoveredIndex;
  int _inactivityLockMinutes = AppSettingsService.defaultInactivityLockMinutes;
  Timer? _inactivityTimer;
  Object? _vaultsError;

  VaultHomePageController({
    required this.auth,
    required VaultRepository repository,
  }) : vaultController = VaultController(repository) {
    fileOperationsController = FileOperationsController(vaultController);
    searchController = vault_search.SearchController(vaultController);

    // Listen to controllers for updates
    vaultController.addListener(_onVaultStateChanged);
    fileOperationsController.addListener(notifyListeners);
    searchController.addListener(notifyListeners);

    loadVaults();
    _loadSettings();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    editorController.dispose();
    vaultController.removeListener(_onVaultStateChanged);
    vaultController.dispose();
    fileOperationsController.dispose();
    searchController.dispose();
    ContentCache.instance.clear();
    super.dispose();
  }

  int get inactivityLockMinutes => _inactivityLockMinutes;
  String? get accountEmail => auth.email;

  /// Why the vault list couldn't be loaded, if it couldn't.
  Object? get vaultsError => _vaultsError;

  void _onVaultStateChanged() {
    if (vaultController.isVaultOpen) {
      if (_inactivityTimer == null) resetInactivityTimer();
    } else {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
    }
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    _inactivityLockMinutes =
        await AppSettingsService.getInactivityLockMinutes();
    resetInactivityTimer();
    notifyListeners();
  }

  Future<void> loadVaults() async {
    try {
      await vaultController.loadVaults();
      _vaultsError = null;
    } catch (e) {
      _vaultsError = e;
    }
    notifyListeners();
  }

  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    if (!vaultController.isVaultOpen || _inactivityLockMinutes <= 0) {
      return;
    }
    _inactivityTimer = Timer(
      Duration(minutes: _inactivityLockMinutes),
      lockVaultDueToInactivity,
    );
  }

  void lockVaultDueToInactivity() {
    if (!vaultController.isVaultOpen) return;
    closeVault();
  }

  Future<void> showAppSettings(BuildContext context) async {
    final result = await showAppSettingsDialog(
      context,
      currentMinutes: _inactivityLockMinutes,
    );
    if (result == null) return;
    await AppSettingsService.setInactivityLockMinutes(result);
    _inactivityLockMinutes = result;
    resetInactivityTimer();
    notifyListeners();
  }

  int? get hoveredIndex => _hoveredIndex;
  bool get loading =>
      vaultController.loading || fileOperationsController.loading;

  void setHoveredIndex(int? index) {
    _hoveredIndex = index;
    notifyListeners();
  }

  /// Shows the account's vaults and opens the chosen one.
  Future<void> openVault({required BuildContext context}) async {
    await loadVaults();
    if (_vaultsError != null) throw _vaultsError!;
    if (!context.mounted) return;
    final vault = await showVaultListDialog(
      context,
      vaults: vaultController.vaults,
    );
    if (vault == null || !context.mounted) return;
    await openVaultAt(vault, context: context);
  }

  Future<void> openVaultAt(
    CloudVault vault, {
    required BuildContext context,
  }) async {
    if (!await _saveBeforeLeaving(context) || !context.mounted) return;
    while (true) {
      final pw = await promptForPasswordWithVerification(
        context,
        title: '${vault.name} password',
      );
      if (pw == null || !context.mounted) return;

      showLoadingDialog(context, message: 'Unlocking vault...');
      Object? error;
      try {
        await vaultController.unlock(vault, pw);
      } catch (e) {
        error = e;
      }
      if (!context.mounted) return;
      Navigator.of(context).pop(); // loading dialog

      if (error is WrongPasswordException) {
        await showErrorDialog(
          context,
          title: 'Incorrect Password',
          message: 'The password you entered is incorrect. Please try again.',
        );
        if (!context.mounted) return;
        continue;
      }
      if (error != null) {
        await showErrorDialog(
          context,
          title: 'Error',
          message: 'Failed to open vault: $error',
        );
        return;
      }
      break;
    }

    _resetEditor();
    resetInactivityTimer();
    await _performAutoBackupIfEnabled();
  }

  Future<void> createVault({required BuildContext context}) async {
    String? initialName;
    while (true) {
      final name = await promptForName(
        context,
        title: 'Create New Vault',
        label: 'Vault name',
        initialValue: initialName,
      );
      if (name == null || name.trim().isEmpty || !context.mounted) return;
      final vaultName = name.trim();
      if (vaultController.vaults.any((v) => v.name == vaultName)) {
        await showErrorDialog(
          context,
          title: 'Vault Already Exists',
          message:
              'A vault named "$vaultName" already exists. Please choose a '
              'different name.',
        );
        if (!context.mounted) return;
        initialName = vaultName;
        continue;
      }

      final pw = await promptForPasswordCreation(
        context,
        title: 'Set a password for this vault',
      );
      if (pw == null || pw.isEmpty || !context.mounted) return;
      if (!await _saveBeforeLeaving(context) || !context.mounted) return;

      showLoadingDialog(context, message: 'Creating and opening vault...');
      Object? error;
      try {
        await vaultController.createVault(vaultName, pw);
      } catch (e) {
        error = e;
      }
      if (!context.mounted) return;
      Navigator.of(context).pop(); // loading dialog
      if (error is VaultNameTakenException) {
        await showErrorDialog(
          context,
          title: 'Vault Already Exists',
          message: error.toString(),
        );
        if (!context.mounted) return;
        initialName = vaultName;
        continue;
      }
      if (error != null) throw error;
      break;
    }
    _resetEditor();
    resetInactivityTimer();
  }

  /// Uploads a vault folder (e.g. one from before vaults were synced) or a
  /// backup ZIP to the account, then opens it.
  Future<void> importVault({required BuildContext context}) async {
    final source = await showImportSourceDialog(context);
    if (source == null || !context.mounted) return;

    Map<String, Uint8List> files;
    String suggestedName;
    switch (source) {
      case ImportSource.folder:
        final dir = await fs.getDirectoryPath();
        if (dir == null) return;
        files = await VaultArchive.readFolder(dir);
        suggestedName = p.basename(dir);
      case ImportSource.backupZip:
        final file = await fs.openFile(
          acceptedTypeGroups: [
            const fs.XTypeGroup(label: 'ZIP files', extensions: ['zip']),
          ],
        );
        if (file == null) return;
        files = VaultArchive.readZip(await file.readAsBytes());
        suggestedName = p
            .basenameWithoutExtension(file.name)
            .replaceAll(RegExp(r'_backup_\d{4}-\d{2}-\d{2}$'), '');
    }
    while (true) {
      if (!context.mounted) return;
      final name = await promptForName(
        context,
        title: 'Import Vault',
        label: 'Vault name',
        initialValue: suggestedName,
      );
      if (name == null || name.trim().isEmpty || !context.mounted) return;

      showLoadingDialog(context, message: 'Uploading encrypted files...');
      Object? error;
      CloudVault? vault;
      try {
        vault = await VaultArchive.import(
          vaultController.repository,
          name.trim(),
          files,
        );
      } catch (e) {
        error = e;
      }
      if (!context.mounted) return;
      Navigator.of(context).pop(); // loading dialog

      if (error is VaultNameTakenException) {
        await showErrorDialog(
          context,
          title: 'Vault Already Exists',
          message: '${error.toString()} Please choose a different name.',
        );
        if (!context.mounted) return;
        suggestedName = name.trim();
        continue;
      }
      if (error is NotAVaultException) {
        await showErrorDialog(
          context,
          title: 'Not a Vault',
          message:
              'No valid .vault_marker was found. Pick the vault folder itself '
              '(the one containing .vault_marker), or a File Vault backup.',
        );
        return;
      }
      if (error != null) throw error;

      await loadVaults();
      if (context.mounted) await openVaultAt(vault!, context: context);
      return;
    }
  }

  Future<void> signOut(BuildContext context) async {
    if (!await _saveBeforeLeaving(context) || !context.mounted) return;
    await signOutAndForgetDevice(
      context,
      auth: auth,
      repository: vaultController.repository,
      beforeSignOut: closeVault,
    );
  }

  /// Saves pending edits before switching vault. Returns false if they
  /// couldn't be saved and the user should stay.
  Future<bool> _saveBeforeLeaving(BuildContext context) async {
    if (!fileOperationsController.dirty) return true;
    await saveCurrentFile(context: context);
    return !fileOperationsController.dirty;
  }

  void _resetEditor() {
    fileOperationsController.closeFile();
    searchController.clearSearch();
    editorController.clear();
    ContentCache.instance.clear();
  }

  Future<void> closeVault() async {
    final session = vaultController.session;
    // Back up (if enabled) while the session is still available.
    if (session != null) await _performAutoBackupIfEnabled();
    if (vaultController.session != session) return;
    vaultController.closeVault();
    _resetEditor();
  }

  Future<void> openFile(VaultItem file, {BuildContext? context}) async {
    if (fileOperationsController.dirty) {
      await saveCurrentFile(context: context);
      // Unsaved edits remain (e.g. external-change dialog dismissed); stay.
      if (fileOperationsController.dirty) return;
    }

    await fileOperationsController.openFile(file);
    _showOpenedContent();
  }

  void _showOpenedContent() {
    final content = fileOperationsController.openedContent;
    if (content != null) {
      editorController.text = content.content;
      editorController.selection = TextSelection.collapsed(
        offset: content.content.length,
      );
    }
  }

  Future<void> createNewFile(BuildContext context) async {
    final name = await promptForName(context);
    if (name == null || name.trim().isEmpty) return;
    if (context.mounted && !await _saveBeforeLeaving(context)) return;

    await fileOperationsController.createNewFile(name.trim());
    editorController.text = '';
    editorController.selection = const TextSelection.collapsed(offset: 0);

    // Trigger search if there's an active query
    searchController.triggerSearch();
  }

  Future<void> saveCurrentFile({BuildContext? context}) async {
    try {
      await fileOperationsController.saveCurrentFile(editorController.text);
    } on FileChangedExternallyException {
      final source = fileOperationsController.openedContent?.item;
      if (context == null || !context.mounted || source == null) rethrow;
      final choice = await showExternalChangeDialog(
        context,
        fileName: source.name,
      );
      switch (choice) {
        case ExternalChangeChoice.overwrite:
          await fileOperationsController.saveCurrentFile(
            editorController.text,
            overwrite: true,
          );
        case ExternalChangeChoice.reload:
          await fileOperationsController.openFile(source);
          _showOpenedContent();
        case ExternalChangeChoice.cancel:
          break;
      }
    }
  }

  Future<void> renameFile(BuildContext context, VaultItem file) async {
    final currentNameNoExt = file.name.replaceAll(
      RegExp(r'\.fva$', caseSensitive: false),
      '',
    );

    final newName = await promptForName(
      context,
      title: 'Rename file',
      label: 'New name (without extension)',
      initialValue: currentNameNoExt,
    );

    if (newName == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    await fileOperationsController.renameFile(file, trimmed);

    // Trigger search if there's an active query
    searchController.triggerSearch();
  }

  Future<void> deleteFile(BuildContext context, VaultItem file) async {
    final confirm = await confirmDeletion(context, fileName: file.name);
    if (!confirm) return;

    final wasOpen = fileOperationsController.openedContent?.item.id == file.id;
    await fileOperationsController.deleteFile(file);
    if (wasOpen) editorController.clear();

    // Trigger search if there's an active query
    searchController.triggerSearch();
  }

  void onContentChanged() {
    if (!fileOperationsController.dirty) {
      fileOperationsController.setDirty(true);
    }
  }

  void handleSaveShortcut(BuildContext context) {
    if (vaultController.isVaultOpen &&
        !loading &&
        fileOperationsController.openedContent != null &&
        fileOperationsController.dirty) {
      saveCurrentFile(context: context);
    }
  }

  Future<bool> backupVault(BuildContext context) async {
    final vault = vaultController.vault;
    if (vault == null) {
      throw Exception('No vault is currently open');
    }

    final result = await showBackupDialog(context, vaultName: vault.name);
    if (result == null) return false; // User cancelled, not an error

    await _performBackup(result.selectedPath);
    // Save the backup path for next time
    await BackupPathsService.saveBackupPath(result.selectedPath);
    return true;
  }

  /// Perform automatic backup if enabled for the vault
  Future<void> _performAutoBackupIfEnabled() async {
    try {
      final vault = vaultController.vault;
      if (vault == null || !vault.autoBackupEnabled) return;

      // The backup folder is per device (e.g. this PC's OneDrive folder).
      final lastBackupPath = await BackupPathsService.getLastBackupPath();
      if (lastBackupPath == null) return; // No backup path configured

      // Delete previous backup files before creating new one
      await BackupPathsService.deletePreviousBackups(
        vault.name,
        lastBackupPath,
      );

      final backupFileName = BackupPathsService.generateBackupFileName(
        vault.name,
        lastBackupPath,
      );

      await _performBackup(backupFileName);
    } catch (e) {
      // Silently fail auto backups to not interrupt user workflow
    }
  }

  /// Show auto backup settings dialog
  Future<void> showAutoBackupSettings(BuildContext context) async {
    final vault = vaultController.vault;
    if (vault == null) return;

    final result = await showAutoBackupSettingsDialog(
      context,
      vault.autoBackupEnabled,
    );
    if (result == null) return;

    await vaultController.setAutoBackupEnabled(result);
    // If enabling auto backup and no backup path is set, prompt user to set one
    if (result && await BackupPathsService.getLastBackupPath() == null) {
      if (!context.mounted) return;
      final backupResult = await backupVault(context);
      if (!backupResult && context.mounted) {
        // User cancelled the backup, so disable auto backup
        await vaultController.setAutoBackupEnabled(false);
        if (context.mounted) {
          await showInfoDialog(
            context,
            title: 'Auto Backup Disabled',
            message: 'Auto backup was disabled because no backup location was configured.',
          );
        }
      }
    }
  }

  /// Downloads the vault's encrypted files and writes them, with its marker,
  /// to a ZIP at [outputPath].
  Future<void> _performBackup(String outputPath) async {
    final session = vaultController.session;
    if (session == null) throw Exception('No vault is currently open');
    final zip = await VaultArchive.buildBackupZip(
      session.vault,
      session.storage,
    );
    await File(outputPath).writeAsBytes(zip, flush: true);
  }
}
