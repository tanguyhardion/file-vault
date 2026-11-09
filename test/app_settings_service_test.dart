import 'package:file_vault/services/app_settings_service.dart';
import 'package:file_vault/theme/app_accent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to 5 minutes', () async {
    expect(await AppSettingsService.getInactivityLockMinutes(), 5);
  });

  test('persists a custom timeout', () async {
    await AppSettingsService.setInactivityLockMinutes(15);
    expect(await AppSettingsService.getInactivityLockMinutes(), 15);
  });

  test('clamps out-of-range values', () async {
    await AppSettingsService.setInactivityLockMinutes(-3);
    expect(await AppSettingsService.getInactivityLockMinutes(), 0);

    await AppSettingsService.setInactivityLockMinutes(999);
    expect(await AppSettingsService.getInactivityLockMinutes(), 240);
  });

  test('accent color defaults to teal and persists', () async {
    expect(await AppSettingsService.getAccent(), AppAccent.teal);
    await AppSettingsService.setAccent(AppAccent.purple);
    expect(await AppSettingsService.getAccent(), AppAccent.purple);
  });

  test('an unknown stored accent falls back to the default', () async {
    SharedPreferences.setMockInitialValues({'accentColor': 'chartreuse'});
    expect(await AppSettingsService.getAccent(), AppAccent.defaultAccent);
  });
}
