import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../models/vault_models.dart';
import '../services/recent_vaults_service.dart';
import '../services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/vault_service.dart';
import '../widgets/widgets.dart';
import 'vault_controller.dart';
import 'file_operations_controller.dart';
import 'search_controller.dart' as vault_search;
import '../services/content_cache.dart';
import 'dart:io';

class VaultHomePageController extends ChangeNotifier {
  final VaultController vaultController = VaultController();
  late final FileOperationsController fileOperationsController;
  late final vault_search.SearchController searchController;

  final TextEditingController editorController = TextEditingController();
  List<String> _recentVaults = [];
  int? _hoveredIndex;

  VaultHomePageController() {
    fileOperationsController = FileOperationsController(vaultController);
    searchController = vault_search.SearchController(vaultController);

    // Listen to controllers for updates
    vaultController.addListener(notifyListeners);
    fileOperationsController.addListener(notifyListeners);
    searchController.addListener(notifyListeners);

    _loadRecent();
  }

  @override
  void dispose() {
    editorController.dispose();
    vaultController.dispose();
    fileOperationsController.dispose();
    searchController.dispose();
    super.dispose();
  }

  List<String> get recentVaults => _recentVaults;
  int? get hoveredIndex => _hoveredIndex;
  bool get loading =>
      vaultController.loading || fileOperationsController.loading;

  void setHoveredIndex(int? index) {
    _hoveredIndex = index;
    notifyListeners();
  }

  Future<void> _loadRecent() async {
    final list = await RecentVaultsService.getRecent();
    // Filter out folders that no longer exist
    final validList = <String>[];
    for (final path in list) {
      if (Directory(path).existsSync()) {
        validList.add(path);
      }
    }
    // If any were removed, update persistent storage
    if (validList.length != list.length) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(RecentVaultsService.prefsKey, validList);
    }
    _recentVaults = validList;
    notifyListeners();
  }

  Future<void> openVault({BuildContext? context}) async {
    final dir = await getDirectoryPath();
    if (dir == null || context == null || !context.mounted) return;
    await openVaultAt(dir, context: context);
  }

  Future<void> openVaultAt(String dir, {BuildContext? context}) async {
    // Check if folder exists before proceeding
    if (!Directory(dir).existsSync()) {
      if (context != null && context.mounted) {
        await showErrorDialog(
          context,
          title: 'Vault Not Found',
          message:
              "The selected vault folder could not be found. The path might have changed or the folder may have been deleted.",
        );
      }
      // Remove from recent vaults and persistent storage
      final prefs = await SharedPreferences.getInstance();
      final current = await RecentVaultsService.getRecent();
      final updated = current.where((e) => e != dir).toList();
      await prefs.setStringList(RecentVaultsService.prefsKey, updated);
      await _loadRecent();
      return;
    }
    if (context == null) {
      throw ArgumentError('Context is required for password prompt');
    }

    // Check marker file first before prompting for password
    final hasMarker = await vaultController.checkVaultMarker(dir);
    if (!hasMarker && context.mounted) {
      // Check if there are existing .fva files in the directory
      final existingFiles = await VaultService.listVaultFiles(dir);
      final hasExistingFiles = existingFiles.isNotEmpty;

      String dialogTitle;
      String dialogContent;

      if (hasExistingFiles) {
        dialogTitle = 'Vault marker missing';
        dialogContent =
            'This folder contains ${existingFiles.length} encrypted file(s) but is missing a vault marker. This might be an existing vault that lost its marker file. Would you like to restore the marker?';
      } else {
        dialogTitle = 'Folder not recognized as a vault';
        dialogContent =
            'The selected folder does not contain a vault marker file. Would you like to mark it as a vault? This will allow you to use it as a vault.';
      }

      bool shouldMark = false;
      if (context.mounted) {
        final result = await showVaultMarkerDialog(
          context,
          title: dialogTitle,
          content: dialogContent,
          confirmText: hasExistingFiles ? 'Restore Marker' : 'Mark as Vault',
        );
        shouldMark = result == true;
      }
      if (shouldMark && context.mounted) {
        // Prompt for password before restoring marker
        String? restorePassword = await promptForPasswordCreation(
          context,
          title: 'Set a password for the restored vault',
        );
        if (restorePassword == null || restorePassword.isEmpty) {
          // User cancelled or entered empty password
          return;
        }
        await vaultController.createVaultMarkerOnly(
          dir,
          password: restorePassword,
        );
      } else {
        return; // User cancelled, don't proceed
      }
    }

    // Now prompt for password with verification
    String? pw;
    bool passwordVerified = false;

    while (!passwordVerified) {
      if (!context.mounted) return;
      final ctx = context;
      pw = await promptForPasswordWithVerification(
        ctx,
        title: 'Vault password',
      );
      if (pw == null) return;

      // Show loading dialog during verification
      if (!ctx.mounted) return;
      showLoadingDialog(ctx, message: 'Verifying password...');

      try {
        // First validate the vault directory
        await vaultController.openVault(dir, pw);

        // Verify password by attempting to decrypt a file if any exist
        final files = await vaultController.verifyPasswordForVault(dir, pw);

        // Close loading dialog
        if (ctx.mounted) {
          Navigator.of(ctx).pop();
        }

        if (files != null) {
          // Password is correct, set the vault as open
          vaultController.setVaultOpen(dir, pw, files);
          passwordVerified = true;

          // Perform automatic backup if enabled
          await _performAutoBackupIfEnabled(dir);
        } else {
          // Show error and retry
          if (ctx.mounted) {
            await showErrorDialog(
              ctx,
              title: 'Incorrect Password',
              message:
                  'The password you entered is incorrect. Please try again.',
            );
          }
          // No need to call vaultController.closeVault() since vault wasn't opened yet
        }
      } catch (e) {
        // Close loading dialog
        if (ctx.mounted) {
          Navigator.of(ctx).pop();
        }

        // Other errors during vault opening
        if (ctx.mounted) {
          await showErrorDialog(
            ctx,
            title: 'Error',
            message: 'Failed to open vault: $e',
          );
        }
        return;
      }
    }

    if (passwordVerified) {
      fileOperationsController.closeFile();
      searchController.clearSearch();
      editorController.clear();
      await _loadRecent();
    }
  }

  Future<void> createVault({BuildContext? context}) async {
    // Prompt for parent folder
    final parentDir = await getDirectoryPath();
    if (parentDir == null) return;

    String? vaultName;
    String vaultFolderName = '';
    String vaultDirPath = '';
    Directory vaultDir;

    // Loop until a valid, non-existing folder name is entered or user cancels
    while (true) {
      if (context != null && context.mounted) {
        vaultName = await promptForName(
          context,
          title: 'Vault name',
          label: 'Vault folder name',
        );
      } else {
        throw ArgumentError('Context is required for vault name prompt');
      }
      if (vaultName == null || vaultName.trim().isEmpty) return;
      vaultFolderName = vaultName.trim();

      vaultDirPath =
          parentDir +
          (parentDir.endsWith("/") || parentDir.endsWith("\\")
              ? ""
              : Platform.pathSeparator) +
          vaultFolderName;
      vaultDir = Directory(vaultDirPath);
      if (await vaultDir.exists()) {
        // Show error dialog if folder exists, then prompt again
        if (context.mounted) {
          await showErrorDialog(
            context,
            title: 'Folder Already Exists',
            message:
                'A folder with the name "$vaultFolderName" already exists. Please choose a different name.',
          );
        }
        // Continue loop to prompt again
        continue;
      }
      // Valid name, break loop
      break;
    }

    // Create the vault folder inside the parent directory
    await vaultDir.create(recursive: true);

    // Prompt for password
    String? pw;
    if (context.mounted) {
      pw = await promptForPasswordCreation(
        context,
        title: 'Set a password for this vault',
      );
      // Show 'Creating and opening vault...' dialog
      if (context.mounted) {
        showLoadingDialog(context, message: 'Creating and opening vault...');
      }
    } else {
      throw ArgumentError('Context is required for password prompt');
    }
    if (pw == null || pw.isEmpty) return;

    await vaultController.createVault(vaultDirPath, pw);
    // Dismiss the vault creation dialog
    if (context.mounted) {
      Navigator.of(context).pop();
    }
    fileOperationsController.closeFile();
    searchController.clearSearch();
    editorController.clear();
    await _loadRecent();
  }

  void closeVault() async {
    final vaultDir = vaultController.vaultDir;

    // Perform automatic backup if enabled before closing
    if (vaultDir != null) {
      await _performAutoBackupIfEnabled(vaultDir);
    }

    vaultController.closeVault();
    fileOperationsController.closeFile();
    searchController.clearSearch();
    editorController.clear();
    // Clear cached decrypted file contents
    ContentCache.instance.clear();
  }

  Future<void> showRecentVaults(BuildContext context) async {
    if (_recentVaults.isEmpty) {
      throw Exception('No recent vaults found');
    }

    final String? selectedPath = await showRecentVaultsDialog(
      context,
      recentVaults: _recentVaults,
      displayNameMapper: (path) => RecentVaultsService.displayName(path),
      itemBuilder: (path, displayName, onTap) => RecentVaultItem(
        vaultPath: path,
        displayName: displayName,
        onTap: onTap,
        showHoverEffect: false,
      ),
    );

    if (selectedPath != null && context.mounted) {
      await openVaultAt(selectedPath, context: context);
    }
  }

  Future<void> openFile(VaultFileEntry file) async {
    if (fileOperationsController.dirty) {
      await saveCurrentFile();
    }

    await fileOperationsController.openFile(file);

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

    await fileOperationsController.createNewFile(name.trim());
    editorController.text = '';
    editorController.selection = const TextSelection.collapsed(offset: 0);

    // Trigger search if there's an active query
    searchController.triggerSearch();
  }

  Future<void> saveCurrentFile() async {
    await fileOperationsController.saveCurrentFile(editorController.text);
  }

  Future<void> renameFile(BuildContext context, VaultFileEntry file) async {
    final currentNameNoExt = file.fileName.replaceAll(
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

  Future<void> deleteFile(BuildContext context, VaultFileEntry file) async {
    final confirm = await confirmDeletion(context, fileName: file.fileName);
    if (!confirm) return;

    await fileOperationsController.deleteFile(file);

    if (fileOperationsController.openedContent?.source.fullPath ==
        file.fullPath) {
      editorController.clear();
    }

    // Trigger search if there's an active query
    searchController.triggerSearch();
  }

  void onContentChanged() {
    if (!fileOperationsController.dirty) {
      fileOperationsController.setDirty(true);
    }
  }

  void handleSaveShortcut() {
    if (vaultController.vaultPassword != null &&
        !loading &&
        fileOperationsController.openedContent != null &&
        fileOperationsController.dirty) {
      saveCurrentFile();
    }
  }

  Future<void> openFolderInExplorer(String path) async {
    // Open the folder using platform-specific command.
    if (Platform.isWindows) {
      // Use explorer to open the folder.
      await Process.run('explorer', [path]);
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
      return;
    }
    if (Platform.isLinux) {
      // Try xdg-open commonly available on Linux desktops.
      await Process.run('xdg-open', [path]);
      return;
    }
    throw UnsupportedError('Opening folder is not supported on this platform');
  }

  Future<bool> backupVault(BuildContext context) async {
    final vaultDir = vaultController.vaultDir;
    if (vaultDir == null) {
      throw Exception('No vault is currently open');
    }

    final vaultName = p.basename(vaultDir);
    final result = await showBackupDialog(context, vaultName: vaultName);

    if (result == null) return false; // User cancelled, not an error

    try {
      await _performBackup(vaultDir, result.selectedPath);
      // Save the backup path for next time
      await BackupPathsService.saveBackupPath(result.selectedPath);
      return true; // Success
    } catch (e) {
      rethrow;
    }
  }

  /// Perform automatic backup if enabled for the vault
  Future<void> _performAutoBackupIfEnabled(String vaultDir) async {
    try {
      final isAutoBackupEnabled = await vaultController.getAutoBackupEnabled(
        vaultDir,
      );
      if (!isAutoBackupEnabled) return;

      final lastBackupPath = await BackupPathsService.getLastBackupPath();
      if (lastBackupPath == null) return; // No backup path configured

      final vaultName = p.basename(vaultDir);
      final backupFileName = BackupPathsService.generateBackupFileName(
        vaultName,
        lastBackupPath,
      );

      await _performBackup(vaultDir, backupFileName);
    } catch (e) {
      // Silently fail auto backups to not interrupt user workflow
      // Could optionally log this error or show a non-blocking notification
    }
  }

  /// Show auto backup settings dialog
  Future<void> showAutoBackupSettings(BuildContext context) async {
    final vaultDir = vaultController.vaultDir;
    if (vaultDir == null) return;

    final currentSetting = await vaultController.getAutoBackupEnabled(vaultDir);
    final result = await showAutoBackupSettingsDialog(context, currentSetting);

    if (result != null) {
      await vaultController.setAutoBackupEnabled(vaultDir, result);
      // If enabling auto backup and no backup path is set, prompt user to set one
      if (result && await BackupPathsService.getLastBackupPath() == null) {
        if (context.mounted) {
          final backupResult = await backupVault(context);
          if (!backupResult && context.mounted) {
            // User cancelled the backup, so disable auto backup
            await vaultController.setAutoBackupEnabled(vaultDir, false);
            await showInfoDialog(
              context,
              title: 'Auto Backup Disabled',
              message:
                  'Auto backup was disabled because no backup location was configured.',
            );
          }
        }
      }
    }
  }

  /// Core backup implementation shared by manual and automatic backups
  Future<void> _performBackup(String vaultDir, String outputPath) async {
    // Create archive
    final archive = Archive();
    final directory = Directory(vaultDir);

    // Add all files from the vault directory to the archive
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: vaultDir);
        final bytes = await entity.readAsBytes();
        final file = ArchiveFile(relativePath, bytes.length, bytes);
        archive.addFile(file);
      }
    }

    // Encode the archive to ZIP format
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('Failed to create ZIP archive');
    }

    // Write the ZIP file
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(zipData);
  }
}
