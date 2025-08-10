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

Future<String?> promptForPasswordWithVerification(
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
                if (controller.text.isEmpty) return null;
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
                if (controller.text.isEmpty) return;
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
                  if (controller.text.isEmpty) return;
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

Future<String?> promptForName(
  BuildContext context, {
  String title = 'Enter name',
  String label = 'Name',
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

Future<bool?> showVaultMarkerDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmText,
}) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

void showLoadingDialog(BuildContext context, {String message = 'Loading...'}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Text(message),
        ],
      ),
    ),
  );
}

Future<void> showErrorDialog(
  BuildContext context, {
  String title = 'Error',
  required String message,
}) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<String?> showRecentVaultsDialog(
  BuildContext context, {
  required List<String> recentVaults,
  required String Function(String) displayNameMapper,
  required Widget Function(String path, String displayName, VoidCallback onTap) itemBuilder,
}) async {
  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Recent Vaults',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 400,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: recentVaults.length,
          itemBuilder: (context, index) {
            final path = recentVaults[index];
            final displayName = displayNameMapper(path);
            return itemBuilder(path, displayName, () => Navigator.of(context).pop(path));
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
