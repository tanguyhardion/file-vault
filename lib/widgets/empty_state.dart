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
        ],
      ),
    );
  }
}
