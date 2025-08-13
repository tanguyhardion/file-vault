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

Future<void> showInfoDialog(
  BuildContext context, {
  String title = 'Information',
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

Future<bool?> showAutoBackupSettingsDialog(
  BuildContext context,
  bool currentSetting,
) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => _AutoBackupSettingsDialog(currentSetting: currentSetting),
  );
}

class _AutoBackupSettingsDialog extends StatefulWidget {
  final bool currentSetting;

  const _AutoBackupSettingsDialog({required this.currentSetting});

  @override
  State<_AutoBackupSettingsDialog> createState() =>
      _AutoBackupSettingsDialogState();
}

class _AutoBackupSettingsDialogState extends State<_AutoBackupSettingsDialog> {
  late bool _autoBackupEnabled;

  @override
  void initState() {
    super.initState();
    _autoBackupEnabled = widget.currentSetting;
  }

  @override
  Widget build(BuildContext context) {
    return DialogWrapper(
      title: const Text('Auto Backup Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Automatically backup your vault when opening and closing it.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Switch(
                value: _autoBackupEnabled,
                onChanged: (value) {
                  setState(() {
                    _autoBackupEnabled = value;
                  });
                },
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Enable automatic backup')),
            ],
          ),
          if (_autoBackupEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Backups will be saved to your last used backup location.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () => Navigator.of(context).pop(_autoBackupEnabled),
      confirmText: 'Save',
    );
  }
}
