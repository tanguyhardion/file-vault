import 'package:flutter/material.dart';

import '../../controllers/vault_home_page_controller.dart';
import '../../services/cloud/cloud_vaults.dart';
import '../content/content_editor.dart';
import '../content/empty_state.dart';

class VaultMainContent extends StatelessWidget {
  final VaultHomePageController controller;
  final void Function(CloudVault vault) onOpenVault;
  final VoidCallback onShowAllVaults;

  const VaultMainContent({
    super.key,
    required this.controller,
    required this.onOpenVault,
    required this.onShowAllVaults,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.fileOperationsController.openedContent == null) {
      return EmptyState(
        vaults: controller.vaultController.vaults,
        onOpenVault: onOpenVault,
        onShowAllVaults: onShowAllVaults,
        isVaultOpen: controller.vaultController.isVaultOpen,
      );
    }

    return ContentEditor(
      content: controller.fileOperationsController.openedContent!,
      controller: controller.editorController,
      dirty: controller.fileOperationsController.dirty,
      loading: controller.loading,
      onSave: () => controller.saveCurrentFile(context: context),
      onChanged: (v) => controller.onContentChanged(),
    );
  }
}
