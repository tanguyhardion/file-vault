import 'package:flutter/material.dart';

class RecentVaultItem extends StatelessWidget {
  final String vaultPath;
  final String displayName;
  final VoidCallback onTap;
  final bool showHoverEffect;

  const RecentVaultItem({
    super.key,
    required this.vaultPath,
    required this.displayName,
    required this.onTap,
    this.showHoverEffect = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.folder),
        title: Text(
          displayName,
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
        onTap: onTap,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        hoverColor: showHoverEffect
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : null,
      ),
    );
  }
}
