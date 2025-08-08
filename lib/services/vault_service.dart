import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/vault_models.dart';

class VaultService {
  static const fvaExtension = '.fva';

  /// Lists .fva files in a directory (non-recursive).
  static Future<List<VaultFileEntry>> listVaultFiles(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final entries = <VaultFileEntry>[];
    await for (final ent in dir.list(recursive: false, followLinks: false)) {
      if (ent is File && p.extension(ent.path).toLowerCase() == fvaExtension) {
        entries.add(
          VaultFileEntry(
            fileName: p.basename(ent.path),
            fullPath: ent.absolute.path,
          ),
        );
      }
    }
    // Sort by name for stable UI
    entries.sort((a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
    return entries;
  }

  /// Reads raw bytes of an .fva file strictly in-memory.
  static Future<Uint8List> readVaultFileBytes(String fullPath) async {
    final file = File(fullPath);
    return await file.readAsBytes();
  }

  /// Writes encrypted bytes to a new .fva file in the vault dir.
  /// Returns the created VaultFileEntry.
  static Future<VaultFileEntry> writeVaultFileBytes({
    required String dirPath,
    required String fileNameWithoutExt,
    required Uint8List encryptedBytes,
  }) async {
    final safeName = _sanitizeFileName(fileNameWithoutExt);
    final targetPath = p.join(dirPath, '$safeName$fvaExtension');
    final file = File(targetPath);
    await file.writeAsBytes(encryptedBytes, flush: true);
    return VaultFileEntry(fileName: p.basename(targetPath), fullPath: file.absolute.path);
  }

  /// Overwrites an existing .fva file with new encrypted bytes.
  static Future<void> overwriteVaultFileBytes({
    required String fullPath,
    required Uint8List encryptedBytes,
  }) async {
    final file = File(fullPath);
    await file.writeAsBytes(encryptedBytes, flush: true);
  }

  static String _sanitizeFileName(String input) {
    var name = input.trim();
    if (name.isEmpty) name = 'untitled';
    // Basic invalid chars for Windows and others
    const invalid = ['\\', '/', ':', '*', '?', '"', '<', '>', '|'];
    for (final ch in invalid) {
      name = name.replaceAll(ch, '_');
    }
    // Remove trailing dots/spaces
    name = name.replaceAll(RegExp(r'[ .]+$'), '');
    return name.isEmpty ? 'untitled' : name;
  }
}
