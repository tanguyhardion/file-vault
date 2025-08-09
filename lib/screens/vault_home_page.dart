import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/vault_home_page_controller.dart';
import '../shortcuts/save_intent.dart';
import '../widgets/vault_header.dart';
import '../widgets/file_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/content_editor.dart';

class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key});

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  late final VaultHomePageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VaultHomePageController();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
            const SaveIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (intent) {
              _controller.handleSaveShortcut();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(appBar: _buildAppBar(), body: _buildBody()),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('File Vault'),
      actions: [
        // Create new vault first
        IconButton(
          tooltip: 'Create new vault',
          icon: const Icon(Icons.create_new_folder_outlined),
          onPressed: _onCreateVault,
        ),
        Container(
          width: 1,
          height: kToolbarHeight - 32,
          color: Divider.createBorderSide(context).color,
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        ),
        // Group: Open vault, Open recent, Close vault
        IconButton(
          tooltip: 'Open vault',
          icon: const Icon(Icons.folder_open),
          onPressed: _onOpenVault,
        ),
        IconButton(
          tooltip: 'Open recent vaults',
          icon: const Icon(Icons.history),
          onPressed: _onShowRecentVaults,
        ),
        if (_controller.vaultController.vaultDir != null)
          IconButton(
            tooltip: 'Close vault',
            icon: const Icon(Icons.close),
            onPressed: _controller.closeVault,
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    return Row(
      children: [
        // Left pane: file list
        SizedBox(
          width: 260,
          child: Stack(
            children: [
              Column(
                children: [
                  VaultHeader(vaultDir: _controller.vaultController.vaultDir),
                  _buildSearchBar(),
                  Expanded(child: _buildFileList()),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24, // Space from bottom
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 180, // Set desired button width
                    child: _buildNewFileButton(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Main view
        Expanded(child: _buildMainContent()),
      ],
    );
  }

  Widget _buildNewFileButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: _controller.vaultController.isVaultOpen
              ? () => _onCreateNewFile()
              : null,
          icon: const Icon(Icons.note_add),
          label: const Text('New secret file'),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    if (!_controller.vaultController.isVaultOpen) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _controller.searchController.searchController,
          decoration: InputDecoration(
            hintText: 'Search files...',
            hintStyle: const TextStyle(fontSize: 14),
            prefixIcon: _controller.searchController.isSearching
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                : const Icon(Icons.search, size: 18),
            suffixIcon: _controller.searchController.hasSearchQuery
                ? IconButton(
                    iconSize: 18,
                    icon: const Icon(Icons.clear),
                    onPressed: _controller.searchController.clearSearch,
                  )
                : null,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18.0)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return Expanded(
      child: _controller.vaultController.vaultDir == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Open a vault folder to see your secret files'),
              ),
            )
          : FileList(
              files:
                  _controller.searchController.filteredFiles.isNotEmpty ||
                      _controller.searchController.hasSearchQuery
                  ? _controller.searchController.filteredFiles
                  : _controller.vaultController.files,
              openedContent: _controller.fileOperationsController.openedContent,
              hoveredIndex: _controller.hoveredIndex,
              onHoverChanged: _controller.setHoveredIndex,
              onOpenFile: (file) => _onOpenFile(file),
              onRename: (file) => _onRenameFile(file),
              onDelete: (file) => _onDeleteFile(file),
            ),
    );
  }

  Widget _buildMainContent() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.fileOperationsController.openedContent == null) {
      return EmptyState(
        recentVaults: _controller.recentVaults,
        onOpenRecent: (dir) => _onOpenRecent(dir),
      );
    }

    return ContentEditor(
      content: _controller.fileOperationsController.openedContent!,
      controller: _controller.editorController,
      dirty: _controller.fileOperationsController.dirty,
      loading: _controller.loading,
      onSave: _controller.saveCurrentFile,
      onChanged: (v) => _controller.onContentChanged(),
    );
  }

  Future<void> _onOpenVault() async {
    try {
      await _controller.openVault(context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _onOpenRecent(String dir) async {
    try {
      await _controller.openVaultAt(dir, context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _onCreateVault() async {
    try {
      await _controller.createVault(context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _onShowRecentVaults() async {
    try {
      await _controller.showRecentVaults(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _onOpenFile(dynamic file) async {
    try {
      await _controller.openFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to decrypt: $e')));
      }
    }
  }

  Future<void> _onCreateNewFile() async {
    try {
      await _controller.createNewFile(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  Future<void> _onRenameFile(dynamic file) async {
    try {
      await _controller.renameFile(context, file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to rename: $e')));
      }
    }
  }

  Future<void> _onDeleteFile(dynamic file) async {
    try {
      await _controller.deleteFile(context, file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }
}
