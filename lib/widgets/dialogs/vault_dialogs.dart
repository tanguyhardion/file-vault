import 'package:flutter/material.dart';
import 'dialog_wrapper.dart';

Future<String?> showRecentVaultsDialog(
  BuildContext context, {
  required List<String> recentVaults,
  required String Function(String) displayNameMapper,
  required Widget Function(String path, String displayName, VoidCallback onTap)
      itemBuilder,
}) async {
  return await showDialog<String>(
    context: context,
    builder: (context) => DialogWrapper(
      title: Text(
        'Recent Vaults',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 400,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: recentVaults.length,
          itemBuilder: (context, index) {
            final path = recentVaults[index];
            final displayName = displayNameMapper(path);
            return itemBuilder(
              path,
              displayName,
              () => Navigator.of(context).pop(path),
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
