import 'package:flutter/material.dart';


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
                    final vaultName = vaultPath.split(RegExp(r'[/\\]')).last;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(
                          vaultName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          vaultPath,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => onOpenRecent(vaultPath),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
