import 'package:flutter/material.dart';
import 'dialog_wrapper.dart';
import 'password_validation.dart';

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
          void validateAndSubmit() {
            final validation = PasswordValidation.validatePasswords(
              passwordController.text,
              confirmController.text,
            );
            if (validation != null) {
              setState(() => errorText = validation);
              return;
            }
            result = passwordController.text;
            Navigator.of(ctx).pop();
          }

          return DialogWrapper(
            title: Text(title),
            onEnterPressed: validateAndSubmit,
            onCancel: () => Navigator.of(ctx).pop(),
            onConfirm: validateAndSubmit,
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
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                  onSubmitted: (_) => validateAndSubmit(),
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
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
          onSubmitted: (_) => submit(),
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

  void submit() {
    if (controller.text.isEmpty) return;
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
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
          onSubmitted: (_) => submit(),
        ),
      );
    },
  );
  return result;
}
