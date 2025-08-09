import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../models/vault_models.dart';
import '../services/recent_vaults_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/recent_vault_item.dart';
import 'vault_controller.dart';
import 'file_operations_controller.dart';
import 'search_controller.dart' as vault_search;

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
    if (dir == null) return;
    await openVaultAt(dir, context: context);
  }

  Future<void> openVaultAt(String dir, {BuildContext? context}) async {
    String? pw;
    if (context != null) {
      pw = await promptForPassword(context, title: 'Vault password');
    } else {
      throw ArgumentError('Context is required for password prompt');
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
  }

  Future<void> createVault({BuildContext? context}) async {
    final dir = await getDirectoryPath();
    if (dir == null) return;

    String? pw;
    if (context != null) {
      pw = await promptForPasswordCreation(
        context,
        title: 'Set a password for this vault',
      );
    } else {
      throw ArgumentError('Context is required for password prompt');
    }
    if (pw == null || pw.isEmpty) return;

    vaultController.createVault(dir, pw);
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

    if (selectedPath != null) {
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
