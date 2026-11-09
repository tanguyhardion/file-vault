import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../services/app_settings_service.dart';
import '../../theme/app_accent.dart';
import '../../theme/appearance.dart';
import 'dialog_wrapper.dart';

/// App settings: inactivity lock and accent color. Returns the new lock
/// timeout, or null if cancelled. The accent color is previewed while the
/// dialog is open and saved with it.
Future<int?> showAppSettingsDialog(
  BuildContext context, {
  required int currentMinutes,
}) async {
  final appearance = Appearance.of(context);
  final original = appearance.value;
  final minutes = await showDialog<int>(
    context: context,
    builder: (ctx) => _AppSettingsDialog(currentMinutes: currentMinutes),
  );
  if (minutes == null) appearance.value = original; // Undo the preview.
  return minutes;
}

class _AppSettingsDialog extends StatefulWidget {
  final int currentMinutes;

  const _AppSettingsDialog({required this.currentMinutes});

  @override
  State<_AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends State<_AppSettingsDialog> {
  late final TextEditingController _minutesController;
  late final AppearanceController _appearance = Appearance.of(context);
  late final AppAccent _originalAccent = _appearance.value;
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

  Future<void> _submit() async {
    final minutes = _parseMinutes();
    if (minutes == null) {
      setState(() {
        _errorText =
            'Enter a number between ${AppSettingsService.minInactivityLockMinutes} and ${AppSettingsService.maxInactivityLockMinutes}. Use 0 to disable.';
      });
      return;
    }
    final accent = _appearance.value;
    if (accent != _originalAccent) await _appearance.save(accent);
    if (mounted) Navigator.of(context).pop(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentChanged = _appearance.value != _originalAccent;
    return DialogWrapper(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
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
            const SizedBox(height: 24),
            Text('Accent color', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Colors the app and its icon.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            AccentPicker(
              selected: _appearance.value,
              onSelected: (accent) =>
                  setState(() => _appearance.value = accent),
            ),
            if (accentChanged && Platform.isAndroid) ...[
              const SizedBox(height: 12),
              Text(
                'The home screen icon changes when you leave the app.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      confirmText: 'Save',
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: _submit,
    );
  }
}

/// A row of color swatches, one per [AppAccent].
class AccentPicker extends StatelessWidget {
  final AppAccent selected;
  final ValueChanged<AppAccent> onSelected;

  const AccentPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final accent in AppAccent.values)
          _Swatch(
            accent: accent,
            scheme: ColorScheme.fromSeed(
              seedColor: Color(accent.seedArgb),
              brightness: brightness,
              dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
            ),
            selected: accent == selected,
            onTap: () => onSelected(accent),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final AppAccent accent;
  final ColorScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.accent,
    required this.scheme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: accent.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: accent.label,
        child: Material(
          color: scheme.primary,
          // Selected swatches morph from a circle to a rounded square.
          shape: selected
              ? const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                )
              : const CircleBorder(),
          animationDuration: Durations.short4,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 44,
              child: selected
                  ? Icon(Icons.check, color: scheme.onPrimary)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
