import 'package:material_ui/material_ui.dart';

import '../../services/cloud/cloud_vaults.dart';
import '../vault/vault_list_item.dart';
import 'dialog_wrapper.dart';

/// Lets the user pick one of their vaults.
Future<CloudVault?> showVaultListDialog(
  BuildContext context, {
  required List<CloudVault> vaults,
}) async {
  return await showDialog<CloudVault>(
    context: context,
    builder: (context) => DialogWrapper(
      title: Text(
        'Open Vault',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 400,
        height: 300, // Set a fixed height to enable scrolling
        child: vaults.isEmpty
            ? const Center(child: Text('No vaults yet. Create or import one.'))
            : ListView.builder(
                itemCount: vaults.length,
                itemBuilder: (context, index) {
                  final vault = vaults[index];
                  return VaultListItem(
                    vault: vault,
                    onTap: () => Navigator.of(context).pop(vault),
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
}

enum ImportSource { folder, backupZip }

/// Asks whether to import a vault folder or a backup ZIP.
Future<ImportSource?> showImportSourceDialog(BuildContext context) {
  return showDialog<ImportSource>(
    context: context,
    builder: (ctx) => DialogWrapper(
      title: const Text('Import Vault'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Upload an existing vault to your account. Files are uploaded '
              'still encrypted and keep their vault password.',
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Vault folder'),
              subtitle: const Text('A folder containing .vault_marker'),
              onTap: () => Navigator.of(ctx).pop(ImportSource.folder),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Backup ZIP'),
              subtitle: const Text('A backup made by File Vault'),
              onTap: () => Navigator.of(ctx).pop(ImportSource.backupZip),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}
