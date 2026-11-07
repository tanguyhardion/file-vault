import 'package:flutter/material.dart';

class VaultHeader extends StatelessWidget {
  final String? vaultName;

  const VaultHeader({super.key, required this.vaultName});

  @override
  Widget build(BuildContext context) {
    final name = vaultName;
    return ListTile(
      title: Text(
        name ?? 'No vault opened',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        name == null ? 'Open, create or import a vault' : 'Synced vault',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
