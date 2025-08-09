import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class RecentVaultsService {
  RecentVaultsService._();
  static const _prefsKey = 'recentVaultDirs';
  static const _maxItems = 8;

  static Future<List<String>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? <String>[];
    // Deduplicate while preserving order
    final seen = <String>{};
    final deduped = <String>[];
    for (final e in raw) {
      if (e.trim().isEmpty) continue;
      final n = _norm(e);
      if (seen.add(n)) deduped.add(e);
      if (deduped.length >= _maxItems) break;
    }
    return deduped;
  }

  static Future<void> add(String dirPath) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getRecent();
    final norm = _norm(dirPath);

    // Move to front if exists
    final updated = <String>[dirPath];
    for (final e in current) {
      if (_norm(e) != norm) updated.add(e);
      if (updated.length >= _maxItems) break;
    }
    await prefs.setStringList(_prefsKey, updated);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static String displayName(String dirPath) => p.basename(dirPath);

  static String _norm(String path) => p.normalize(path).toLowerCase();
}
