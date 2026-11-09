import 'package:file_vault/services/app_settings_service.dart';
import 'package:file_vault/theme/app_accent.dart';
import 'package:file_vault/theme/appearance.dart';
import 'package:file_vault/widgets/dialogs/app_settings_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppearanceController appearance;
  int? result;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appearance = AppearanceController();
    result = null;
  });

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      Appearance(
        controller: appearance,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showAppSettingsDialog(
                context,
                currentMinutes: 5,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('previews a color and reverts it on cancel', (tester) async {
    await openSettings(tester);
    await tester.tap(find.byTooltip('Purple'));
    await tester.pump();
    expect(appearance.value, AppAccent.purple);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(appearance.value, AppAccent.teal);
    expect(await AppSettingsService.getAccent(), AppAccent.teal);
  });

  testWidgets('saves the chosen color', (tester) async {
    await openSettings(tester);
    await tester.tap(find.byTooltip('Orange'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    // Saving writes settings and calls the (absent) native icon switcher.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(result, 5);
    expect(appearance.value, AppAccent.orange);
    expect(await AppSettingsService.getAccent(), AppAccent.orange);
  });
}
