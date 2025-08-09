import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class VaultHeader extends StatelessWidget {
  final String? vaultDir;

  const VaultHeader({super.key, required this.vaultDir});

  @override
  Widget build(BuildContext context) {
    final dir = vaultDir;
    final name = dir == null ? 'No vault opened' : p.basename(dir);
    return ListTile(
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: dir == null ? const Text('Open or create a vault') : Text(dir),
    );
  }
}
