import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/app_settings_service.dart';
import 'app_accent.dart';

/// The accent color in use. Settings previews a color by setting [value] and
/// keeps it with [save].
class AppearanceController extends ValueNotifier<AppAccent> {
  AppearanceController([super.value = AppAccent.defaultAccent]);

  static Future<AppearanceController> load() async =>
      AppearanceController(await AppSettingsService.getAccent());

  /// Persists [accent] and switches the app icon to match.
  Future<void> save(AppAccent accent) async {
    value = accent;
    await AppSettingsService.setAccent(accent);
    await AppIconService.apply(accent);
  }
}

/// Provides the [AppearanceController] to the widget tree.
class Appearance extends InheritedNotifier<AppearanceController> {
  const Appearance({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppearanceController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Appearance>()!.notifier!;
}

/// Switches the app icon to the one of an accent color.
///
/// Android: enables that accent's launcher alias once the app is in the
/// background (MainActivity.kt). Windows: changes the window and taskbar icon
/// of the running app; the .exe and its shortcuts keep the default icon.
abstract final class AppIconService {
  static const _channel = MethodChannel('file_vault/app_icon');

  static Future<void> apply(AppAccent accent) async {
    try {
      await _channel.invokeMethod<void>('setAccent', accent.id);
    } on MissingPluginException {
      // Platforms (and tests) without the native side keep their icon.
    } on PlatformException {
      // A failed icon switch must not break changing the theme.
    }
  }
}
