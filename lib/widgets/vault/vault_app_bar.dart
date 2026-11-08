import 'package:material_ui/material_ui.dart';

import '../../controllers/vault_home_page_controller.dart';

class VaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VaultHomePageController controller;
  final VoidCallback onOpenVault;
  final VoidCallback onImportVault;
  final VoidCallback onSignOut;
  final VoidCallback onCreateVault;
  final VoidCallback onBackupVault;
  final VoidCallback onAutoBackupSettings;
  final VoidCallback onAppSettings;

  const VaultAppBar({
    super.key,
    required this.controller,
    required this.onOpenVault,
    required this.onImportVault,
    required this.onSignOut,
    required this.onCreateVault,
    required this.onBackupVault,
    required this.onAutoBackupSettings,
    required this.onAppSettings,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('File Vault'),
      scrolledUnderElevation: 0.0,
      surfaceTintColor: Colors.transparent,
      elevation: 0.0,
      actions: [
        // Open vault
        IconButton(
          tooltip: 'Open vault (Ctrl+O)',
          icon: const Icon(Icons.folder_open),
          onPressed: onOpenVault,
        ),
        // Create new vault
        IconButton(
          tooltip: 'Create new vault (Ctrl+N)',
          icon: const Icon(Icons.create_new_folder_outlined),
          onPressed: onCreateVault,
        ),
        // Import a vault folder or backup
        IconButton(
          tooltip: 'Import vault folder or backup (Ctrl+I)',
          icon: const Icon(Icons.upload_file),
          onPressed: onImportVault,
        ),
        // Backup buttons (only shown when vault is open)
        if (controller.vaultController.isVaultOpen) ...[
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
        IconButton(
          tooltip: 'Settings (Ctrl+,)',
          icon: const Icon(Icons.settings_outlined),
          onPressed: onAppSettings,
        ),
        PopupMenuButton<String>(
          tooltip: 'Account',
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (v) {
            if (v == 'signout') onSignOut();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Text(controller.accountEmail ?? 'Signed in'),
            ),
            const PopupMenuItem(value: 'signout', child: Text('Sign out')),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
