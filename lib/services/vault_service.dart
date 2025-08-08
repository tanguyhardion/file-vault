import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/vault_models.dart';
import 'vault_crypto.dart';

/// Vault file format (v1):
/// [0..3]   magic bytes: 0x46 0x56 0x41 0x01 ("FVA\x01")
/// [4..7]   u32 headerLen (little-endian)
/// [8..8+N) header json bytes (utf8) - non-sensitive meta
/// [..end]  encrypted payload: salt(16) | nonce(12) | ciphertext | tag(16)
class VaultService {
  Future<void> saveVault({
    required String vaultPath,
    required List<VaultEntry> entries,
    required String password,
  }) async {
    // Serialize payload (JSON of entries)
    final payload = VaultPayload(entries: entries).toBytes();
    final enc = await VaultCrypto.encrypt(payload, password);

    final header = VaultHeaderMeta(
      app: 'File Vault',
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    ).toBytes();

    final headerLen = header.length;
    final headerLenLE = Uint8List(4)
      ..buffer.asByteData().setUint32(0, headerLen, Endian.little);

    final fileBytes = <int>[]
      ..addAll(VaultMagic.magicBytes)
      ..addAll(headerLenLE)
      ..addAll(header)
      ..addAll(enc);

    final file = File(vaultPath);
    await file.writeAsBytes(fileBytes, flush: true);
  }

  Future<List<VaultEntry>> loadVault({
    required String vaultPath,
    required String password,
  }) async {
    final file = File(vaultPath);
    final bytes = await file.readAsBytes();
    if (bytes.length < 8) {
      throw StateError('File too small');
    }
    // Check magic
    for (int i = 0; i < VaultMagic.magicBytes.length; i++) {
      if (bytes[i] != VaultMagic.magicBytes[i]) {
        throw StateError('Not a valid .fva file');
      }
    }
    // Header size
    final headerLen = ByteData.sublistView(Uint8List.fromList(bytes.sublist(4, 8))).getUint32(0, Endian.little);
    final headerStart = 8;
    final headerEnd = headerStart + headerLen;
    if (headerEnd > bytes.length) {
      throw StateError('Invalid header length');
    }
    final headerBytes = bytes.sublist(headerStart, headerEnd);
    // Parse, but we do nothing with it beyond validation
    VaultHeaderMeta.fromBytes(headerBytes);

    final encrypted = bytes.sublist(headerEnd);
    final plain = await VaultCrypto.decrypt(encrypted, password);
    final payload = VaultPayload.fromBytes(plain);
    return payload.entries;
  }

  /// Build entries from a directory recursively
  Future<List<VaultEntry>> collectEntriesFromDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw ArgumentError('Directory not found: $dirPath');
    }
    final List<VaultEntry> result = [];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final rel = p.relative(entity.path, from: dirPath);
        final data = await entity.readAsBytes();
        result.add(VaultEntry(path: rel.replaceAll('\\', '/'), data: data));
      }
    }
    return result;
  }

  /// Extract entries to a directory; returns count of written files
  Future<int> extractEntriesToDirectory(List<VaultEntry> entries, String outDir) async {
    int count = 0;
    for (final e in entries) {
      final outPath = p.join(outDir, e.path);
      final parent = Directory(p.dirname(outPath));
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      final f = File(outPath);
      await f.writeAsBytes(e.data, flush: true);
      count++;
    }
    return count;
  }
}
