import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import 'dialog_wrapper.dart';

class VaultCreationDetails {
  final String name;
  final String path;

  VaultCreationDetails({required this.name, required this.path});
}

Future<VaultCreationDetails?> promptForVaultCreationDetails(
  BuildContext context, {
  String title = 'Create New Vault',
}) async {
  final nameController = TextEditingController();
  final pathController = TextEditingController();
  VaultCreationDetails? result;

  void submit() {
    final name = nameController.text.trim();
    final path = pathController.text.trim();
    if (name.isNotEmpty && path.isNotEmpty) {
      result = VaultCreationDetails(name: name, path: path);
      Navigator.of(context).pop();
    }
  }

  Future<void> browsePath() async {
    final dir = await getDirectoryPath();
    if (dir != null) {
      pathController.text = dir;
    }
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return DialogWrapper(
        title: Text(title),
        onEnterPressed: submit,
        onCancel: () => Navigator.of(ctx).pop(),
        onConfirm: submit,
        confirmText: 'Create',
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Vault Name'),
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pathController,
                      decoration: const InputDecoration(labelText: 'Parent Folder Path'),
                      onSubmitted: (_) => submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: browsePath,
                    child: const Text('Browse'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result;
}

Future<String?> promptForText(
  BuildContext context, {
  String title = 'Enter text',
  String label = 'Text',
}) async {
  final controller = TextEditingController();
  String? result;

  void submit() {
    result = controller.text;
    Navigator.of(context).pop();
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return DialogWrapper(
        title: Text(title),
        onEnterPressed: submit,
        useCtrlEnter:
            true, // Ctrl+Enter submits for multiline input; Enter inserts newlines.
        onCancel: () => Navigator.of(ctx).pop(),
        onConfirm: submit,
        confirmText: 'Save',
        content: TextField(
          controller: controller,
          maxLines: 10,
          minLines: 5,
          decoration: InputDecoration(labelText: label),
        ),
      );
    },
  );
  return result;
}

Future<String?> promptForName(
  BuildContext context, {
  String title = 'Enter name',
  String label = 'Name',
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  String? result;

  void submit() {
    result = controller.text;
    Navigator.of(context).pop();
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return DialogWrapper(
        title: Text(title),
        onEnterPressed: submit,
        onCancel: () => Navigator.of(ctx).pop(),
        onConfirm: submit,
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
          onSubmitted: (_) => submit(),
        ),
      );
    },
  );
  return result;
}
