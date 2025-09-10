import 'package:flutter/material.dart';

import '../../controllers/vault_home_page_controller.dart';

class VaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VaultHomePageController controller;
  final VoidCallback onOpenVault;
  final VoidCallback onShowRecentVaults;
  final VoidCallback onCreateVault;
  final VoidCallback onBackupVault;
  final VoidCallback onAutoBackupSettings;

  const VaultAppBar({
    super.key,
    required this.controller,
    required this.onOpenVault,
    required this.onShowRecentVaults,
    required this.onCreateVault,
    required this.onBackupVault,
    required this.onAutoBackupSettings,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('File Vault'),
      actions: [
        // Open vault
        IconButton(
          tooltip: 'Open vault (Ctrl+O)',
          icon: const Icon(Icons.folder_open),
          onPressed: onOpenVault,
        ),
        // Open recent vaults
        IconButton(
          tooltip: 'Open recent vaults (Ctrl+R)',
          icon: const Icon(Icons.history),
          onPressed: onShowRecentVaults,
        ),
        // Create new vault
        IconButton(
          tooltip: 'Create new vault (Ctrl+N)',
          icon: const Icon(Icons.create_new_folder_outlined),
          onPressed: onCreateVault,
        ),
        // Backup buttons (only shown when vault is open)
        if (controller.vaultController.vaultDir != null) ...[
          // Separator
          Container(
            width: 1,
            height: kToolbarHeight - 32,
            color: Divider.createBorderSide(context).color,
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          ),
          IconButton(
            tooltip: 'Backup vault (Ctrl+B)',
            icon: const Icon(Icons.backup),
            onPressed: onBackupVault,
          ),
          IconButton(
            tooltip: 'Auto backup settings (Ctrl+Shift+B)',
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: onAutoBackupSettings,
          ),
          // Separator
          Container(
            width: 1,
            height: kToolbarHeight - 32,
            color: Divider.createBorderSide(context).color,
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          ),
          // Close vault
          IconButton(
            tooltip: 'Close vault (Ctrl+W)',
            icon: const Icon(Icons.close),
            onPressed: controller.closeVault,
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
