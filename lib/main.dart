import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'theme/appearance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearance = await AppearanceController.load();
  // Windows sets the window icon on every launch; Android keeps its alias.
  unawaited(AppIconService.apply(appearance.value));
  runApp(FileVaultApp(appearance: appearance));
}
