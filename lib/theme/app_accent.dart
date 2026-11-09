// Pure Dart (no Flutter import): `tool/generate_icons.dart` imports this to
// render one launcher icon per accent.

/// Accent colors the user can pick. Each one seeds the app's color scheme and
/// has a matching app icon.
enum AppAccent {
  teal('Teal', 0xFF009688),
  blue('Blue', 0xFF2196F3),
  indigo('Indigo', 0xFF3F51B5),
  purple('Purple', 0xFF9C27B0),
  pink('Pink', 0xFFE91E63),
  red('Red', 0xFFF44336),
  orange('Orange', 0xFFFF9800),
  green('Green', 0xFF4CAF50);

  const AppAccent(this.label, this.seedArgb);

  static const AppAccent defaultAccent = AppAccent.teal;

  final String label;

  /// Seed for the color scheme (and the icon colors).
  final int seedArgb;

  /// Identifies the accent in settings and in the native icon switchers
  /// (Android activity alias `.Launcher<Name>`, Windows icon resource).
  String get id => name;

  static AppAccent fromId(String? id) => AppAccent.values.firstWhere(
    (a) => a.id == id,
    orElse: () => defaultAccent,
  );
}
