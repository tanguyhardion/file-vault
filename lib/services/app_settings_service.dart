import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  AppSettingsService._();

  static const prefsKeyInactivityLockMinutes = 'inactivityLockMinutes';
  static const defaultInactivityLockMinutes = 5;
  static const minInactivityLockMinutes = 0;
  static const maxInactivityLockMinutes = 240;

  /// Minutes of inactivity before the open vault is locked.
  /// `0` disables automatic lock.
  static Future<int> getInactivityLockMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(prefsKeyInactivityLockMinutes);
    return _clamp(value ?? defaultInactivityLockMinutes);
  }

  static Future<void> setInactivityLockMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsKeyInactivityLockMinutes, _clamp(minutes));
  }

  static int _clamp(int minutes) {
    if (minutes < minInactivityLockMinutes) {
      return minInactivityLockMinutes;
    }
    if (minutes > maxInactivityLockMinutes) {
      return maxInactivityLockMinutes;
    }
    return minutes;
  }
}
