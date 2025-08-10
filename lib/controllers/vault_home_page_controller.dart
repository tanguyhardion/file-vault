import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../models/vault_models.dart';
import '../services/recent_vaults_service.dart';
import '../services/vault_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/recent_vault_item.dart';
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
    _recentVaults = list;
    notifyListeners();
  }

  Future<void> openVault({BuildContext? context}) async {
    final dir = await getDirectoryPath();
    if (dir == null || context == null || !context.mounted) return;
    await openVaultAt(dir, context: context);
  }

  Future<void> openVaultAt(String dir, {BuildContext? context}) async {
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
        String? restorePassword = await promptForPasswordCreation(context, title: 'Set a password for the restored vault');
        if (restorePassword == null || restorePassword.isEmpty) {
          // User cancelled or entered empty password
          return;
        }
        await vaultController.createVaultMarkerOnly(dir, password: restorePassword);
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
    } else {
      throw ArgumentError('Context is required for password prompt');
    }
    if (pw == null || pw.isEmpty) return;

    await vaultController.createVault(vaultDirPath, pw);
    fileOperationsController.closeFile();
    searchController.clearSearch();
    editorController.clear();
    await _loadRecent();
  }

  void closeVault() {
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
}
