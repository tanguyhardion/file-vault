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
