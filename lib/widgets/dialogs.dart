import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<String?> promptForPasswordCreation(
  BuildContext context, {
  String title = 'Set a password for this vault',
}) async {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  String? result;
  String? errorText;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Shortcuts(
            shortcuts: <LogicalKeySet, Intent>{
              LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (intent) {
                    if (passwordController.text != confirmController.text) {
                      setState(() {
                        errorText = "Passwords do not match";
                      });
                      return null;
                    }
                    if (passwordController.text.isEmpty) {
                      setState(() {
                        errorText = "Password cannot be empty";
                      });
                      return null;
                    }
                    result = passwordController.text;
                    Navigator.of(ctx).pop();
                    return null;
                  },
                ),
              },
              child: AlertDialog(
                title: Text(title),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm Password'),
                      onSubmitted: (_) {
                        if (passwordController.text != confirmController.text) {
                          setState(() {
                            errorText = "Passwords do not match";
                          });
                          return;
                        }
                        if (passwordController.text.isEmpty) {
                          setState(() {
                            errorText = "Password cannot be empty";
                          });
                          return;
                        }
                        result = passwordController.text;
                        Navigator.of(ctx).pop();
                      },
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
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
                      if (passwordController.text != confirmController.text) {
                        setState(() {
                          errorText = "Passwords do not match";
                        });
                        return;
                      }
                      if (passwordController.text.isEmpty) {
                        setState(() {
                          errorText = "Password cannot be empty";
                        });
                        return;
                      }
                      result = passwordController.text;
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
    },
  );
  return result;
}

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
  // Ctrl+Enter submits for multiline input; Enter inserts newlines.
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
        content: Text(
          'Are you sure you want to delete "$fileName"? This cannot be undone.',
        ),
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
