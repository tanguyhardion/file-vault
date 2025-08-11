import 'package:flutter/material.dart';
import 'dialog_wrapper.dart';

/// Shows a blocking dialog with a loading indicator and custom message.
void showLoadingDialog(BuildContext context, {String message = 'Loading...'}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => DialogWrapper(
      showActions: false,
      content: Padding(
  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    ),
  );
}
