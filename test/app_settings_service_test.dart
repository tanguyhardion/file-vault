import 'package:file_vault/services/app_settings_service.dart';
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
}
