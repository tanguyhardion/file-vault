import 'package:material_ui/material_ui.dart';

import 'app_accent.dart';

/// The app's Material 3 Expressive theme.
///
/// `material_ui` only ships part of M3 Expressive so far, so this opts into
/// what exists ([StyleVariant.material3Expressive] icon buttons, the 2024
/// progress indicators) and layers the rest on top through component themes:
/// more vibrant color, a rounder shape scale, buttons that morph to a squarer
/// shape while pressed, and emphasized headline/title type.
abstract final class AppTheme {
  static ThemeData light([AppAccent accent = AppAccent.defaultAccent]) =>
      _build(Brightness.light, accent);
  static ThemeData dark([AppAccent accent = AppAccent.defaultAccent]) =>
      _build(Brightness.dark, accent);

  static ThemeData _build(Brightness brightness, AppAccent accent) {
    // `vibrant` keeps the seed hue but pushes chroma, matching Expressive's
    // bolder color. (`DynamicSchemeVariant.expressive` rotates the primary hue
    // away from the chosen accent.) tool/generate_icons.dart uses the same
    // variant so the app icon matches the theme.
    final scheme = ColorScheme.fromSeed(
      seedColor: Color(accent.seedArgb),
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      textTheme: _emphasize(base.textTheme),
      iconButtonTheme: const IconButtonThemeData(
        variant: StyleVariant.material3Expressive,
      ),
      filledButtonTheme: FilledButtonThemeData(style: _morphingButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _morphingButtonStyle),
      textButtonTheme: TextButtonThemeData(style: _morphingButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _morphingButtonStyle),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppShapes.large),
      ),
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppShapes.large),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppShapes.extraLarge),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppShapes.medium),
      ),
      // Deprecated, but false is how to opt into the 2024 (Expressive) look.
      // ignore: deprecated_member_use
      progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false),
      searchBarTheme: const SearchBarThemeData(
        elevation: WidgetStatePropertyAll(0),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
    );
  }

  /// Buttons rest fully rounded and squish to a rounded rectangle while
  /// pressed; [Material] animates the shape change between the two.
  static final ButtonStyle _morphingButtonStyle = ButtonStyle(
    shape: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.pressed)
          ? const RoundedRectangleBorder(borderRadius: AppShapes.small)
          : const StadiumBorder(),
    ),
    animationDuration: Durations.short4,
  );

  /// Expressive's emphasized type: heavier display, headline and large titles.
  static TextTheme _emphasize(TextTheme t) {
    TextStyle? w(TextStyle? s, FontWeight weight) =>
        s?.copyWith(fontWeight: weight);
    return t.copyWith(
      displayLarge: w(t.displayLarge, FontWeight.w500),
      displayMedium: w(t.displayMedium, FontWeight.w500),
      displaySmall: w(t.displaySmall, FontWeight.w500),
      headlineLarge: w(t.headlineLarge, FontWeight.w500),
      headlineMedium: w(t.headlineMedium, FontWeight.w500),
      headlineSmall: w(t.headlineSmall, FontWeight.w500),
      titleLarge: w(t.titleLarge, FontWeight.w500),
    );
  }
}

/// Corner radii from the M3 Expressive shape scale.
abstract final class AppShapes {
  static const BorderRadius small = BorderRadius.all(Radius.circular(8));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius large = BorderRadius.all(Radius.circular(16));
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(28));
}
