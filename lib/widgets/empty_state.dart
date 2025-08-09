import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'recent_vault_item.dart';


class EmptyState extends StatelessWidget {
  final List<String> recentVaults;
  final void Function(String path) onOpenRecent;

  const EmptyState({
    super.key,
    required this.recentVaults,
    required this.onOpenRecent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 56),
          const SizedBox(height: 12),
          const Text('Select a file to view its content'),
          if (recentVaults.isNotEmpty) ...[
            const SizedBox(height: 32),
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
                  ...recentVaults.take(5).map((vaultPath) {
                    final vaultName = p.basename(vaultPath);
                    return RecentVaultItem(
                      vaultPath: vaultPath,
                      displayName: vaultName,
                      onTap: () => onOpenRecent(vaultPath),
                      showHoverEffect: true,
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
