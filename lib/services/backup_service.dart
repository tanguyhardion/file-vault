import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class BackupPathsService {
  BackupPathsService._();
  static const _prefsKey = 'lastBackupPath';

  /// Get the last used backup directory path
  static Future<String?> getLastBackupPath() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPath = prefs.getString(_prefsKey);

    // Verify the directory still exists before returning it
    if (lastPath != null) {
      final directory = Directory(lastPath);
      if (await directory.exists()) {
        return lastPath;
      } else {
        // Clean up invalid path
        await prefs.remove(_prefsKey);
      }
    }

    return null;
  }

  /// Save the directory path where a backup was saved
  static Future<void> saveBackupPath(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final directoryPath = p.dirname(filePath);
    await prefs.setString(_prefsKey, directoryPath);
  }

  /// Clear the stored backup path
  static Future<void> clearBackupPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Generate a suggested backup file name with the given directory
  static String generateBackupFileName(String vaultName, String directory) {
    final date = DateTime.now().toIso8601String().split('T')[0];
    final fileName = '${vaultName}_backup_$date.zip';
    return p.join(directory, fileName);
  }
}
