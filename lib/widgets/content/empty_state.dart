import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../vault/recent_vault_item.dart';

class EmptyState extends StatelessWidget {
  final List<String> recentVaults;
  final void Function(String path) onOpenRecent;
  final VoidCallback? onShowAllRecent;
  final bool isVaultOpen;

  const EmptyState({
    super.key,
    required this.recentVaults,
    required this.onOpenRecent,
    this.onShowAllRecent,
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
          // If no vault is open, only show recent vaults
          if (!isVaultOpen && recentVaults.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Vaults',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...recentVaults.take(3).map((vaultPath) {
                    final vaultName = p.basename(vaultPath);
                    return RecentVaultItem(
                      vaultPath: vaultPath,
                      displayName: vaultName,
                      onTap: () => onOpenRecent(vaultPath),
                      showHoverEffect: true,
                    );
                  }),
                  if (recentVaults.length > 3 && onShowAllRecent != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: onShowAllRecent,
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
