import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class VaultHeader extends StatelessWidget {
  final String? vaultDir;
  final VoidCallback? onOpenInExplorer;

  const VaultHeader({super.key, required this.vaultDir, this.onOpenInExplorer});

  @override
  Widget build(BuildContext context) {
    final dir = vaultDir;
    final name = dir == null ? 'No vault opened' : p.basename(dir);
    return ListTile(
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: dir == null
          ? const Text('Open or create a vault')
          : Text(dir, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: dir == null
          ? null
          : IconButton(
              tooltip: 'Open in Explorer',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
              onPressed: onOpenInExplorer,
              icon: const Icon(Icons.open_in_new),
            ),
    );
  }
}
