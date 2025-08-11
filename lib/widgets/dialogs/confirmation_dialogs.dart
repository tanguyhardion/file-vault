import 'package:flutter/material.dart';
import 'dialog_wrapper.dart';

Future<bool> confirmDeletion(
  BuildContext context, {
  String title = 'Delete file',
  required String fileName,
}) async {
  var confirm = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return DialogWrapper(
        title: Text(title),
        onCancel: () => Navigator.of(ctx).pop(),
        onConfirm: () {
          confirm = true;
          Navigator.of(ctx).pop();
        },
        cancelText: 'Cancel',
        confirmText: 'Delete',
        isDestructive: true,
        content: Text(
          'Are you sure you want to delete "$fileName"? This cannot be undone.',
        ),
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
    builder: (ctx) => DialogWrapper(
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

Future<void> showErrorDialog(
  BuildContext context, {
  String title = 'Error',
  required String message,
}) async {
  await showDialog(
    context: context,
    builder: (ctx) => DialogWrapper(
      title: Text(title),
      onConfirm: () => Navigator.of(ctx).pop(),
      confirmText: 'OK',
      showActions: true,
      content: Text(message),
    ),
  );
}
