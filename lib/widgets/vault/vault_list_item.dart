import 'package:flutter/material.dart';

import '../../services/cloud/cloud_vaults.dart';

class VaultListItem extends StatelessWidget {
  final CloudVault vault;
  final VoidCallback onTap;
  final bool showHoverEffect;

  const VaultListItem({
    super.key,
    required this.vault,
    required this.onTap,
    this.showHoverEffect = true,
  });

  @override
  Widget build(BuildContext context) {
    final created = vault.createdAt?.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: Text(
          vault.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: created == null
            ? null
            : Text(
                'Created ${created.toIso8601String().split('T').first}',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
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
