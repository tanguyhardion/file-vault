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
        dialogContent = 'This folder contains ${existingFiles.length} encrypted file(s) but is missing a vault marker. This might be an existing vault that lost its marker file. Would you like to restore the marker?';
      } else {
        dialogTitle = 'Folder not recognized as a vault';
        dialogContent = 'The selected folder does not contain a vault marker file. Would you like to mark it as a vault? This will allow you to use it as a vault.';
      }
      
      final shouldMark = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(dialogTitle),
          content: Text(dialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(hasExistingFiles ? 'Restore Marker' : 'Mark as Vault'),
            ),
          ],
        ),
      );
      if (shouldMark == true) {
        await vaultController.createVaultMarkerOnly(dir);
      } else {
        return; // User cancelled, don't proceed
      }
    }

    // Now prompt for password
    String? pw;
    if (context.mounted) {
      pw = await promptForPassword(context, title: 'Vault password');
    }
    if (pw == null || pw.isEmpty) return;

    try {
      await vaultController.openVault(dir, pw);
      fileOperationsController.closeFile();
      searchController.clearSearch();
      editorController.clear();
      await _loadRecent();
    } catch (e) {
      throw Exception('Failed to open vault: $e');
    }
  }  Future<void> createVault({BuildContext? context}) async {
    final dir = await getDirectoryPath();
    if (dir == null) return;

    String? pw;
    if (context != null && context.mounted) {
      pw = await promptForPasswordCreation(
        context,
        title: 'Set a password for this vault',
      );
    } else {
      throw ArgumentError('Context is required for password prompt');
    }
    if (pw == null || pw.isEmpty) return;

    await vaultController.createVault(dir, pw);
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

    final String? selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Recent Vaults',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _recentVaults.length,
            itemBuilder: (context, index) {
              final path = _recentVaults[index];
              final displayName = RecentVaultsService.displayName(path);
              return RecentVaultItem(
                vaultPath: path,
                displayName: displayName,
                onTap: () => Navigator.of(context).pop(path),
                showHoverEffect: false,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
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
    final name = await promptForFilename(context);
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

    final newName = await promptForFilename(
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
