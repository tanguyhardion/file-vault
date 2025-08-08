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
    entries.sort(
      (a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
    );
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
    return VaultFileEntry(
      fileName: p.basename(targetPath),
      fullPath: file.absolute.path,
    );
  }

  /// Overwrites an existing .fva file with new encrypted bytes.
  static Future<void> overwriteVaultFileBytes({
    required String fullPath,
    required Uint8List encryptedBytes,
  }) async {
    final file = File(fullPath);
    await file.writeAsBytes(encryptedBytes, flush: true);
  }

  /// Renames an existing .fva file to a new sanitized name (without extension).
  /// Throws [FileSystemException] if the target already exists.
  static Future<VaultFileEntry> renameVaultFile({
    required String fullPath,
    required String newFileNameWithoutExt,
  }) async {
    final file = File(fullPath);
    if (!await file.exists()) {
      throw FileSystemException('File does not exist', fullPath);
    }
    final dirPath = p.dirname(fullPath);
    final safeName = _sanitizeFileName(newFileNameWithoutExt);
    final newPath = p.join(dirPath, '$safeName$fvaExtension');
    if (p.equals(fullPath, newPath)) {
      // No change in resulting path; return current entry.
      return VaultFileEntry(
        fileName: p.basename(newPath),
        fullPath: file.absolute.path,
      );
    }
    final target = File(newPath);
    if (await target.exists()) {
      throw FileSystemException('A file with that name already exists', newPath);
    }
    final renamed = await file.rename(newPath);
    return VaultFileEntry(
      fileName: p.basename(renamed.path),
      fullPath: renamed.absolute.path,
    );
  }

  /// Deletes an existing .fva file if it exists.
  static Future<void> deleteVaultFile(String fullPath) async {
    final file = File(fullPath);
    if (await file.exists()) {
      await file.delete();
    }
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
