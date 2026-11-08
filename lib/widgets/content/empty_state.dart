import 'package:material_ui/material_ui.dart';

import '../../services/cloud/cloud_vaults.dart';
import '../vault/vault_list_item.dart';

class EmptyState extends StatelessWidget {
  final List<CloudVault> vaults;
  final void Function(CloudVault vault) onOpenVault;
  final VoidCallback? onShowAllVaults;
  final bool isVaultOpen;

  const EmptyState({
    super.key,
    required this.vaults,
    required this.onOpenVault,
    this.onShowAllVaults,
    required this.isVaultOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // If a vault is open, show the "select a file" message
          if (isVaultOpen) ...[
            const Icon(Icons.lock_open, size: 56),
            const SizedBox(height: 12),
            const Text('Select a file to view its content'),
          ],
          if (!isVaultOpen && vaults.isEmpty) ...[
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: 12),
            const Text(
              'No vaults yet. Create one (Ctrl+N), or import an existing '
              'vault folder or backup (Ctrl+I).',
            ),
          ],
          // If no vault is open, show the account's vaults
          if (!isVaultOpen && vaults.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Vaults',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...vaults
                      .take(3)
                      .map(
                        (vault) => VaultListItem(
                          vault: vault,
                          onTap: () => onOpenVault(vault),
                        ),
                      ),
                  if (vaults.length > 3 && onShowAllVaults != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: onShowAllVaults,
                        icon: const Icon(Icons.more_horiz, size: 16),
                        label: const Text('More'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          textStyle: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
