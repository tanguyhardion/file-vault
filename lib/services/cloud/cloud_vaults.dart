import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../storage/vault_storage.dart';
import '../vault_marker.dart';
import 'cloud_client.dart';

/// A vault stored in the database. Holds only its name and marker (salt +
/// password hash); files are in [CloudVaultStorage].
class CloudVault {
  final String id;
  final String name;
  final VaultMarker marker;
  final bool autoBackupEnabled;
  final DateTime? createdAt;

  const CloudVault({
    required this.id,
    required this.name,
    required this.marker,
    this.autoBackupEnabled = false,
    this.createdAt,
  });

  factory CloudVault.fromRow(Map<String, dynamic> row) => CloudVault(
    id: row['id'] as String,
    name: row['name'] as String,
    marker: VaultMarker(
      salt: base64Decode(row['salt'] as String),
      passwordHash: base64Decode(row['password_hash'] as String),
    ),
    autoBackupEnabled: row['auto_backup_enabled'] as bool? ?? false,
    createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
  );

  /// The row as returned by the server (used for the offline copy).
  Map<String, dynamic> toRow() => {
    'id': id,
    'name': name,
    'salt': base64Encode(marker.salt),
    'password_hash': base64Encode(marker.passwordHash),
    'auto_backup_enabled': autoBackupEnabled,
    'created_at': createdAt?.toIso8601String(),
  };

  CloudVault copyWith({bool? autoBackupEnabled}) => CloudVault(
    id: id,
    name: name,
    marker: marker,
    autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
    createdAt: createdAt,
  );
}

/// A vault with that name already exists in the account.
class VaultNameTakenException implements Exception {
  final String name;
  const VaultNameTakenException(this.name);

  @override
  String toString() => 'A vault named "$name" already exists.';
}

/// The signed-in account's vaults.
class CloudVaultRepository {
  static const _table = 'vaults';
  static const _columns =
      'id,name,salt,password_hash,auto_backup_enabled,created_at';

  final CloudClient _client;

  const CloudVaultRepository(this._client);

  CloudVaultStorage storageFor(CloudVault vault) =>
      CloudVaultStorage(_client, vault.id);

  Future<List<CloudVault>> list() async {
    final rows = await _client.select(_table, {
      'select': _columns,
      'order': 'name.asc',
    });
    return rows.map(CloudVault.fromRow).toList();
  }

  /// Creates an empty vault protected by [password].
  Future<CloudVault> create(String name, String password) async {
    // PBKDF2 is slow; keep it off the UI isolate.
    final marker = await Isolate.run(() => VaultMarker.create(password));
    return createWithMarker(name, marker);
  }

  /// Creates a vault from an existing marker (e.g. an imported folder).
  Future<CloudVault> createWithMarker(
    String name,
    VaultMarker marker, {
    bool autoBackupEnabled = false,
  }) async {
    try {
      final row = await _client.insert(_table, {
        'name': name,
        'salt': base64Encode(marker.salt),
        'password_hash': base64Encode(marker.passwordHash),
        'auto_backup_enabled': autoBackupEnabled,
      }, select: _columns);
      return CloudVault.fromRow(row);
    } on CloudException catch (e) {
      if (e.isUniqueViolation) throw VaultNameTakenException(name);
      rethrow;
    }
  }

  Future<CloudVault> setAutoBackupEnabled(
    CloudVault vault,
    bool enabled,
  ) async {
    await _client.update(
      _table,
      {'id': 'eq.${vault.id}'},
      {'auto_backup_enabled': enabled},
    );
    return vault.copyWith(autoBackupEnabled: enabled);
  }

  /// Deletes the vault and all its files.
  Future<void> delete(CloudVault vault) =>
      _client.delete(_table, {'id': 'eq.${vault.id}'});
}

/// A file's metadata and content, read in one request so they match.
class RemoteFile {
  final VaultItem item;
  final Uint8List content;
  const RemoteFile(this.item, this.content);
}

/// A vault's files in the database. Only ciphertext is sent or received.
class CloudVaultStorage implements VaultStorage {
  static const _table = 'vault_files';
  static const _meta = 'id,name,size,version,updated_at';

  final CloudClient _client;
  final String vaultId;

  const CloudVaultStorage(this._client, this.vaultId);

  @override
  Future<List<VaultItem>> listFiles() async {
    final rows = await _client.select(_table, {
      'select': _meta,
      'vault_id': 'eq.$vaultId',
    });
    return rows.map(_item).toList();
  }

  @override
  Future<VaultItem> stat(VaultItem item) async =>
      await statById(item.id) ?? (throw FileMissingException(item.name));

  /// Current metadata of file [id], or null if it doesn't exist.
  Future<VaultItem?> statById(String id) async {
    final rows = await _client.select(_table, {
      'select': _meta,
      'id': 'eq.$id',
    });
    return rows.isEmpty ? null : _item(rows.single);
  }

  /// Metadata and content of the files with [ids] that still exist.
  Future<List<RemoteFile>> readMany(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.select(_table, {
      'select': '$_meta,content',
      'vault_id': 'eq.$vaultId',
      'id': 'in.(${ids.join(',')})',
    });
    return [
      for (final row in rows)
        RemoteFile(_item(row), base64Decode(row['content'] as String)),
    ];
  }

  /// Sets the content and/or name of file [id]. With [ifVersion], only if the
  /// file is still at that version. Returns null if no file matched (it
  /// changed, or was deleted). Throws [NameConflictException].
  Future<VaultItem?> update(
    String id, {
    Uint8List? content,
    String? name,
    String? ifVersion,
  }) async {
    try {
      final rows = await _client.update(
        _table,
        {
          'id': 'eq.$id',
          if (ifVersion != null) 'version': 'eq.$ifVersion',
          'select': _meta,
        },
        {if (content != null) 'content': base64Encode(content), 'name': ?name},
      );
      return rows.isEmpty ? null : _item(rows.single);
    } on CloudException catch (e) {
      if (e.isUniqueViolation) throw NameConflictException(name ?? id);
      rethrow;
    }
  }

  /// Deletes file [id] if it is still at [version]. Returns false if it
  /// changed since (or was already deleted).
  Future<bool> deleteIfVersion(String id, String version) async {
    final rows = await _client.delete(_table, {
      'id': 'eq.$id',
      'version': 'eq.$version',
      'select': 'id',
    });
    return rows.isNotEmpty;
  }

  @override
  Future<Uint8List> read(VaultItem item) async {
    final rows = await _client.select(_table, {
      'select': 'content',
      'id': 'eq.${item.id}',
    });
    if (rows.isEmpty) throw FileMissingException(item.name);
    return base64Decode(rows.single['content'] as String);
  }

  @override
  Future<VaultItem> write(
    VaultItem item,
    Uint8List bytes, {
    String? ifVersion,
  }) async {
    final rows = await _client.update(
      _table,
      {
        'id': 'eq.${item.id}',
        if (ifVersion != null) 'version': 'eq.$ifVersion',
        'select': _meta,
      },
      {'content': base64Encode(bytes)},
    );
    if (rows.isEmpty) {
      // Changed (or deleted) on another device since it was read.
      if (ifVersion != null) throw FileChangedExternallyException();
      throw FileMissingException(item.name);
    }
    return _item(rows.single);
  }

  /// [id] lets the caller choose the row ID (e.g. for a file created offline).
  @override
  Future<VaultItem> create(String name, Uint8List bytes, {String? id}) async {
    try {
      final row = await _client.insert(_table, {
        'id': ?id,
        'vault_id': vaultId,
        'name': name,
        'content': base64Encode(bytes),
      }, select: _meta);
      return _item(row);
    } on CloudException catch (e) {
      if (e.isUniqueViolation) throw NameConflictException(name);
      rethrow;
    }
  }

  @override
  Future<VaultItem> rename(VaultItem item, String newName) async {
    if (item.name == newName) return stat(item);
    try {
      final rows = await _client.update(
        _table,
        {'id': 'eq.${item.id}', 'select': _meta},
        {'name': newName},
      );
      if (rows.isEmpty) throw FileMissingException(item.name);
      return _item(rows.single);
    } on CloudException catch (e) {
      if (e.isUniqueViolation) throw NameConflictException(newName);
      rethrow;
    }
  }

  @override
  Future<void> delete(VaultItem item) =>
      _client.delete(_table, {'id': 'eq.${item.id}'});

  static VaultItem _item(Map<String, dynamic> row) => VaultItem(
    id: row['id'] as String,
    name: row['name'] as String,
    size: (row['size'] as num?)?.toInt() ?? 0,
    version: '${row['version']}',
    lastModified: DateTime.tryParse(row['updated_at'] as String? ?? ''),
  );
}
