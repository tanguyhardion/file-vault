import 'package:flutter/material.dart';

import 'dialog_wrapper.dart';

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
