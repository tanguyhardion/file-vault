import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'cloud/cloud_vaults.dart';
import 'offline/vault_repository.dart';
import 'storage/vault_storage.dart';
import 'vault_marker.dart';
import 'vault_service.dart';

/// The folder or archive has no valid `.vault_marker`.
class NotAVaultException implements Exception {
  @override
  String toString() =>
      'This is not a vault (missing or invalid .vault_marker).';
}

/// Converts between database vaults and the folder/ZIP layout used by backups
/// and by vaults from older versions of the app (`.vault_marker` + `*.fva`).
/// Everything handled here is already encrypted.
class VaultArchive {
  VaultArchive._();

  /// ZIP with the vault's marker and encrypted files, in the same layout as
  /// a vault folder, so it can be imported again.
  static Future<Uint8List> buildBackupZip(
    CloudVault vault,
    VaultStorage storage,
  ) async {
    final archive = Archive();
    final marker = utf8.encode(
      vault.marker.toFileContents(
        createdAt: vault.createdAt,
        autoBackupEnabled: vault.autoBackupEnabled,
      ),
    );
    archive.addFile(ArchiveFile(VaultMarker.fileName, marker.length, marker));
    final files = await storage.listFiles();
    for (final item in files) {
      final bytes = await storage.read(item);
      archive.addFile(ArchiveFile(item.name, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Top-level files of a vault folder.
  static Future<Map<String, Uint8List>> readFolder(String dirPath) async {
    final files = <String, Uint8List>{};
    await for (final ent in Directory(dirPath).list(followLinks: false)) {
      if (ent is File) files[p.basename(ent.path)] = await ent.readAsBytes();
    }
    return files;
  }

  /// Top-level files of a backup ZIP.
  static Map<String, Uint8List> readZip(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final files = <String, Uint8List>{};
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = f.name.replaceAll('\\', '/');
      if (name.contains('/')) continue;
      files[name] = Uint8List.fromList(f.content as List<int>);
    }
    return files;
  }

  /// Creates a database vault named [name] from [files] (marker + .fva).
  /// The vault keeps its password. If an upload fails, nothing is kept.
  static Future<CloudVault> import(
    VaultRepository repo,
    String name,
    Map<String, Uint8List> files, {
    void Function(int done, int total)? onProgress,
  }) async {
    final markerBytes = files[VaultMarker.fileName];
    if (markerBytes == null) throw NotAVaultException();
    final markerText = utf8.decode(markerBytes, allowMalformed: true);
    final marker = VaultMarker.tryParse(markerText);
    if (marker == null) throw NotAVaultException();
    final autoBackup = markerText.contains('auto_backup_enabled: true');

    final encrypted = files.entries
        .where((e) => VaultService.isVaultFileName(e.key))
        .toList();

    final vault = await repo.createWithMarker(
      name,
      marker,
      autoBackupEnabled: autoBackup,
    );
    try {
      // Straight to the server: an import is all or nothing.
      final storage = repo.remoteStorageFor(vault);
      var done = 0;
      onProgress?.call(done, encrypted.length);
      for (final e in encrypted) {
        await storage.create(e.key, e.value);
        onProgress?.call(++done, encrypted.length);
      }
      return vault;
    } catch (_) {
      await repo.delete(vault).catchError((_) {});
      rethrow;
    }
  }
}
