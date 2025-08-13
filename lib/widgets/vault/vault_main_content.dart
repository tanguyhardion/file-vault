import 'package:flutter/material.dart';

import '../../controllers/vault_home_page_controller.dart';
import '../content/content_editor.dart';
import '../content/empty_state.dart';

class VaultMainContent extends StatelessWidget {
  final VaultHomePageController controller;
  final Function(String dir) onOpenRecent;
  final VoidCallback onShowAllRecent;

  const VaultMainContent({
    super.key,
    required this.controller,
    required this.onOpenRecent,
    required this.onShowAllRecent,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.fileOperationsController.openedContent == null) {
      return EmptyState(
        recentVaults: controller.recentVaults,
        onOpenRecent: onOpenRecent,
        onShowAllRecent: onShowAllRecent,
      );
    }

    return ContentEditor(
      content: controller.fileOperationsController.openedContent!,
      controller: controller.editorController,
      dirty: controller.fileOperationsController.dirty,
      loading: controller.loading,
      onSave: controller.saveCurrentFile,
      onChanged: (v) => controller.onContentChanged(),
    );
  }
}
