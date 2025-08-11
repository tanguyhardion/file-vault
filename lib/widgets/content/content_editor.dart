import 'package:flutter/material.dart';

import '../../models/vault_models.dart';

class ContentEditor extends StatelessWidget {
  final DecryptedFileContent content;
  final TextEditingController controller;
  final bool dirty;
  final bool loading;
  final VoidCallback onSave;
  final ValueChanged<String>? onChanged;

  const ContentEditor({
    super.key,
    required this.content,
    required this.controller,
    required this.dirty,
    required this.loading,
    required this.onSave,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            children: [
              Text(
                content.source.fileName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (dirty) ...[
                const SizedBox(width: 8),
                const Tooltip(
                  message: 'Unsaved changes',
                  child: Icon(Icons.circle, size: 10, color: Colors.orange),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Tooltip(
                message: 'Save (Ctrl+S)',
                child: FilledButton.icon(
                  onPressed: (!loading && dirty) ? onSave : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              style: const TextStyle(fontFamily: 'monospace'),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
