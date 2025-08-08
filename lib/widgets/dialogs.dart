import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<String?> promptForPassword(
  BuildContext context, {
  String title = 'Enter password',
}) async {
  final controller = TextEditingController();
  String? result;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                result = controller.text;
                Navigator.of(ctx).pop();
                return null;
              },
            ),
          },
          child: AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (_) {
                result = controller.text;
                Navigator.of(ctx).pop();
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  result = controller.text;
                  Navigator.of(ctx).pop();
                },
                child: const Text('OK'),
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
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Shortcuts(
        // Use Ctrl+Enter to submit for multiline input; Enter keeps inserting newlines.
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
              const ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                result = controller.text;
                Navigator.of(ctx).pop();
                return null;
              },
            ),
          },
          child: AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              maxLines: 10,
              minLines: 5,
              decoration: InputDecoration(labelText: label),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  result = controller.text;
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result;
}

Future<String?> promptForFilename(
  BuildContext context, {
  String title = 'New file name',
  String label = 'File name (without extension)',
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  String? result;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                result = controller.text;
                Navigator.of(ctx).pop();
                return null;
              },
            ),
          },
          child: AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: label),
              autofocus: true,
              onSubmitted: (_) {
                result = controller.text;
                Navigator.of(ctx).pop();
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  result = controller.text;
                  Navigator.of(ctx).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result;
}

Future<bool> confirmDeletion(
  BuildContext context, {
  String title = 'Delete file',
  required String fileName,
}) async {
  var confirm = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text('Are you sure you want to delete "$fileName"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () {
              confirm = true;
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return confirm;
}
