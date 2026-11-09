import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../storage/vault_storage.dart';

/// This device's copy of a vault file, and what still has to be sent to the
/// server.
///
/// Only ciphertext is stored, like in a backup ZIP.
class LocalFile {
  final String id;

  /// Name on this device.
  String name;

  /// Name and version on the server when last synced; null if the file was
  /// created here and never uploaded.
  String? serverName;
  int? serverVersion;

  /// Server version of the stored content, if it is the server's. The content
  /// of a file with [localEdits] is this device's.
  int? contentVersion;

  /// Content changes made here since [serverVersion].
  int localEdits;

  /// Deleted here, not yet on the server.
  bool deleted;

  int size;
  DateTime? updatedAt;

  /// The local [version] the current [serverVersion] was uploaded from, so an
  /// editor still holding that version can keep saving.
  String? pushedFrom;

  LocalFile({
    required this.id,
    required this.name,
    this.serverName,
    this.serverVersion,
    this.contentVersion,
    this.localEdits = 0,
    this.deleted = false,
    this.size = 0,
    this.updatedAt,
    this.pushedFrom,
  });

  /// Has changes the server doesn't have yet.
  bool get isDirty =>
      deleted || serverVersion == null || localEdits > 0 || name != serverName;

  /// The stored content is the current one (local edits, or the server's
  /// latest known version).
  bool get hasCurrentContent =>
      localEdits > 0 ||
      (contentVersion != null && contentVersion == serverVersion);

  /// Opaque version for [VaultItem.version]: the server version, or
  /// `<server version>.<local edits>` while there are local edits.
  String get version => (localEdits == 0 && serverVersion != null)
      ? '$serverVersion'
      : '${serverVersion ?? 0}.$localEdits';

  static bool isLocalVersion(String version) => version.contains('.');

  VaultItem toItem() => VaultItem(
    id: id,
    name: name,
    size: size,
    version: version,
    lastModified: updatedAt,
  );

  /// Mirrors the server's state of the file.
  void adoptServer(VaultItem item) {
    final version = int.parse(item.version);
    // Changed by someone else: an editor's older version no longer maps here.
    if (version != serverVersion) pushedFrom = null;
    name = item.name;
    serverName = item.name;
    serverVersion = version;
    localEdits = 0;
    deleted = false;
    size = item.size;
    updatedAt = item.lastModified;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'serverName': serverName,
    'serverVersion': serverVersion,
    'contentVersion': contentVersion,
    'localEdits': localEdits,
    'deleted': deleted,
    'size': size,
    'updatedAt': updatedAt?.toIso8601String(),
    'pushedFrom': pushedFrom,
  };

  factory LocalFile.fromJson(Map<String, dynamic> j) => LocalFile(
    id: j['id'] as String,
    name: j['name'] as String,
    serverName: j['serverName'] as String?,
    serverVersion: j['serverVersion'] as int?,
    contentVersion: j['contentVersion'] as int?,
    localEdits: j['localEdits'] as int? ?? 0,
    deleted: j['deleted'] as bool? ?? false,
    size: j['size'] as int? ?? 0,
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    pushedFrom: j['pushedFrom'] as String?,
  );
}

/// One account's offline copy of its vaults, on disk:
///
/// ```
/// <root>/vaults.json           vault rows (name, marker)
/// <root>/<vault id>/index.json LocalFile records
/// <root>/<vault id>/<file id>  encrypted content
/// ```
class LocalVaultStore {
  final Future<Directory> Function() _root;
  Directory? _dir;

  LocalVaultStore(this._root);

  /// Store for [email] under [base] (the app support directory).
  factory LocalVaultStore.forAccount(
    Future<Directory> Function() base,
    String email,
  ) {
    // Hex, not base64: Windows file names are case-insensitive.
    final key = utf8
        .encode(email.trim().toLowerCase())
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return LocalVaultStore(
      () async => Directory(p.join((await base()).path, 'offline', key)),
    );
  }

  Future<Directory> _rootDir() async => _dir ??= await _root();

  Future<File> _file(List<String> parts) async =>
      File(p.joinAll([(await _rootDir()).path, ...parts]));

  Future<List<Map<String, dynamic>>?> readVaults() async {
    final json = await _readJson(await _file(['vaults.json']));
    return (json as List?)?.cast<Map<String, dynamic>>();
  }

  Future<void> writeVaults(List<Map<String, dynamic>> rows) async =>
      _writeJson(await _file(['vaults.json']), rows);

  Future<Map<String, LocalFile>> readIndex(String vaultId) async {
    final json = await _readJson(await _file([vaultId, 'index.json']));
    return {
      for (final j in (json as List? ?? const []).cast<Map<String, dynamic>>())
        j['id'] as String: LocalFile.fromJson(j),
    };
  }

  Future<void> writeIndex(String vaultId, Iterable<LocalFile> files) async =>
      _writeJson(await _file([vaultId, 'index.json']), [
        for (final f in files) f.toJson(),
      ]);

  Future<Uint8List?> readContent(String vaultId, String fileId) async {
    final f = await _file([vaultId, _blob(fileId)]);
    return await f.exists() ? f.readAsBytes() : null;
  }

  Future<void> writeContent(
    String vaultId,
    String fileId,
    Uint8List bytes,
  ) async => _writeAtomic(await _file([vaultId, _blob(fileId)]), bytes);

  Future<void> deleteContent(String vaultId, String fileId) async {
    final f = await _file([vaultId, _blob(fileId)]);
    if (await f.exists()) await f.delete();
  }

  /// IDs of the vaults that have a local folder.
  Future<List<String>> storedVaultIds() async {
    final dir = await _rootDir();
    if (!await dir.exists()) return const [];
    return [
      await for (final e in dir.list())
        if (e is Directory) p.basename(e.path),
    ];
  }

  Future<void> deleteVault(String vaultId) async {
    final dir = Directory(p.join((await _rootDir()).path, vaultId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Removes this account's offline copy.
  Future<void> wipe() async {
    final dir = await _rootDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static String _blob(String fileId) => '$fileId.fva';

  static Future<Object?> _readJson(File f) async {
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString());
    } on FormatException {
      return null; // A damaged index is rebuilt from the server.
    }
  }

  static Future<void> _writeJson(File f, Object json) =>
      _writeAtomic(f, utf8.encode(jsonEncode(json)));

  static int _writes = 0;

  /// Write-then-rename, so a crash never leaves a half-written file. Each
  /// write has its own temporary file, so concurrent writes can't mix.
  static Future<void> _writeAtomic(File f, List<int> bytes) async {
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.${pid}_${_writes++}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }
}
