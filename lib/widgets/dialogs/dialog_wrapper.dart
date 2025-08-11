import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Base dialog wrapper with keyboard shortcuts and common structure
class DialogWrapper extends StatelessWidget {
  final Widget? title;
  final Widget content;
  final List<Widget>? actions;
  final VoidCallback? onEnterPressed;
  final bool useCtrlEnter;

  // Common action buttons
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String cancelText;
  final String confirmText;
  final bool isDestructive;
  final bool showActions;

  const DialogWrapper({
    super.key,
    this.title,
    required this.content,
    this.actions,
    this.onEnterPressed,
    this.useCtrlEnter = false,
    this.onCancel,
    this.onConfirm,
    this.cancelText = 'Cancel',
    this.confirmText = 'OK',
    this.isDestructive = false,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    // Build actions - use custom actions if provided, otherwise build common actions
    List<Widget> dialogActions;
    if (actions != null) {
      dialogActions = actions!;
    } else if (showActions) {
      dialogActions = [
        if (onCancel != null)
          TextButton(onPressed: onCancel, child: Text(cancelText)),
        if (onConfirm != null)
          isDestructive
              ? FilledButton.tonal(
                  onPressed: onConfirm,
                  child: Text(confirmText),
                )
              : FilledButton(onPressed: onConfirm, child: Text(confirmText)),
      ];
    } else {
      dialogActions = [];
    }

    Widget dialog = Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.headlineSmall!,
                    child: title!,
                  ),
                ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    title != null ? 20 : 24,
                    24,
                    dialogActions.isEmpty ? 24 : 0,
                  ),
                  child: content,
                ),
              ),
              if (dialogActions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (int i = 0; i < dialogActions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        dialogActions[i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (onEnterPressed != null) {
      final shortcuts = useCtrlEnter
          ? <LogicalKeySet, Intent>{
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.enter,
              ): const ActivateIntent(),
            }
          : <LogicalKeySet, Intent>{
              LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
            };

      dialog = Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                onEnterPressed?.call();
                return null;
              },
            ),
          },
          child: dialog,
        ),
      );
    }

    return dialog;
  }
}
