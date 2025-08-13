import 'package:flutter/material.dart';

import '../../controllers/vault_home_page_controller.dart';
import '../widgets.dart';

class VaultLeftPanel extends StatelessWidget {
  final VaultHomePageController controller;
  final VoidCallback onOpenVaultInExplorer;
  final VoidCallback onCreateNewFile;
  final Function(dynamic file) onOpenFile;
  final Function(dynamic file) onRename;
  final Function(dynamic file) onDelete;

  const VaultLeftPanel({
    super.key,
    required this.controller,
    required this.onOpenVaultInExplorer,
    required this.onCreateNewFile,
    required this.onOpenFile,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Stack(
        children: [
          Column(
            children: [
              VaultHeader(
                vaultDir: controller.vaultController.vaultDir,
                onOpenInExplorer: onOpenVaultInExplorer,
              ),
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
    );
  }

  Widget _buildNewFileButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: controller.vaultController.isVaultOpen
              ? onCreateNewFile
              : null,
          icon: const Icon(Icons.note_add),
          label: const Text('New secret file'),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    if (!controller.vaultController.isVaultOpen) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: controller.searchController.searchController,
          decoration: InputDecoration(
            hintText: 'Search files...',
            hintStyle: const TextStyle(fontSize: 14),
            prefixIcon: controller.searchController.isSearching
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                : const Icon(Icons.search, size: 18),
            suffixIcon: controller.searchController.hasSearchQuery
                ? IconButton(
                    iconSize: 18,
                    icon: const Icon(Icons.clear),
                    onPressed: controller.searchController.clearSearch,
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
    return controller.vaultController.vaultDir == null
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Open a vault folder to see your secret files'),
            ),
          )
        : FileList(
            files:
                controller.searchController.filteredFiles.isNotEmpty ||
                    controller.searchController.hasSearchQuery
                ? controller.searchController.filteredFiles
                : controller.vaultController.files,
            openedContent: controller.fileOperationsController.openedContent,
            hoveredIndex: controller.hoveredIndex,
            onHoverChanged: controller.setHoveredIndex,
            onOpenFile: onOpenFile,
            onRename: onRename,
            onDelete: onDelete,
          );
  }
}
