import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_settings_service.dart';
import 'dialog_wrapper.dart';

Future<int?> showAppSettingsDialog(
  BuildContext context, {
  required int currentMinutes,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _AppSettingsDialog(currentMinutes: currentMinutes),
  );
}

class _AppSettingsDialog extends StatefulWidget {
  final int currentMinutes;

  const _AppSettingsDialog({required this.currentMinutes});

  @override
  State<_AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends State<_AppSettingsDialog> {
  late final TextEditingController _minutesController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController(
      text: '${widget.currentMinutes}',
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  int? _parseMinutes() {
    final raw = _minutesController.text.trim();
    final value = int.tryParse(raw);
    if (value == null) return null;
    if (value < AppSettingsService.minInactivityLockMinutes ||
        value > AppSettingsService.maxInactivityLockMinutes) {
      return null;
    }
    return value;
  }

  void _submit() {
    final minutes = _parseMinutes();
    if (minutes == null) {
      setState(() {
        _errorText =
            'Enter a number between ${AppSettingsService.minInactivityLockMinutes} and ${AppSettingsService.maxInactivityLockMinutes}. Use 0 to disable.';
      });
      return;
    }
    Navigator.of(context).pop(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return DialogWrapper(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lock the currently open vault after a period of inactivity. Pointer movement, clicks, and keyboard input count as activity.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Inactivity lock (minutes)',
              helperText: 'Default is 5. Set 0 to disable auto-lock.',
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      confirmText: 'Save',
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: _submit,
    );
  }
}
