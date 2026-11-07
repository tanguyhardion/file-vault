import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum VaultLocation { local, oneDrive }

/// A vault folder the user added on this device.
class SavedVault {
  final VaultLocation location;

  /// Local folder path, or OneDrive folder item ID.
  final String id;
  final String name;

  /// Human-readable location, e.g. `/storage/emulated/0/Vaults/Personal`.
  final String path;

  const SavedVault({
    required this.location,
    required this.id,
    required this.name,
    required this.path,
  });

  Map<String, dynamic> toJson() => {
    'location': location.name,
    'id': id,
    'name': name,
    'path': path,
  };

  factory SavedVault.fromJson(Map<String, dynamic> json) => SavedVault(
    location: VaultLocation.values.byName(json['location'] as String),
    id: json['id'] as String,
    name: json['name'] as String,
    path: json['path'] as String? ?? '',
  );
}

/// Persists the list of known vaults (locations and names only).
class SavedVaultsStore {
  SavedVaultsStore._();
  static const _prefsKey = 'mobileVaults';

  static Future<List<SavedVault>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    return raw
        .map((e) => SavedVault.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  /// Adds or moves [vault] to the top of the list.
  static Future<void> add(SavedVault vault) async {
    final current = await getAll();
    await _save([vault, ...current.where((v) => !_same(v, vault))]);
  }

  static Future<void> remove(SavedVault vault) async {
    final current = await getAll();
    await _save(current.where((v) => !_same(v, vault)).toList());
  }

  static bool _same(SavedVault a, SavedVault b) =>
      a.location == b.location && a.id == b.id;

  static Future<void> _save(List<SavedVault> vaults) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      vaults.map((v) => jsonEncode(v.toJson())).toList(),
    );
  }
}
