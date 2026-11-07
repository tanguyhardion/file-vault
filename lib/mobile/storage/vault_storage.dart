import 'dart:typed_data';

/// A file inside a vault folder, wherever the folder lives.
class VaultItem {
  /// Backend-specific handle (a OneDrive item ID or a full local path).
  final String id;
  final String name;
  final int size;
  final DateTime? lastModified;

  /// Changes whenever the file changes; used to detect concurrent edits.
  final String version;

  const VaultItem({
    required this.id,
    required this.name,
    required this.size,
    required this.version,
    this.lastModified,
  });
}

/// The vault folder itself no longer exists.
class VaultFolderMissingException implements Exception {
  @override
  String toString() => 'The vault folder no longer exists.';
}

/// A file with the requested name already exists.
class NameConflictException implements Exception {
  final String name;
  const NameConflictException(this.name);

  @override
  String toString() => 'A file named "$name" already exists.';
}

/// Where a vault's (encrypted) files are stored. Implementations only ever
/// receive and return ciphertext.
abstract class VaultStorage {
  /// Files directly inside the vault folder (no subfolders).
  Future<List<VaultItem>> listFiles();

  /// Current metadata of [item].
  Future<VaultItem> stat(VaultItem item);

  Future<Uint8List> read(VaultItem item);

  /// Replaces the content of [item]. If [ifVersion] is given and the file
  /// changed since then, throws `FileChangedExternallyException`.
  Future<VaultItem> write(VaultItem item, Uint8List bytes, {String? ifVersion});

  /// Creates [name]; throws [NameConflictException] if it exists.
  Future<VaultItem> create(String name, Uint8List bytes);

  /// Throws [NameConflictException] if [newName] is taken.
  Future<VaultItem> rename(VaultItem item, String newName);

  Future<void> delete(VaultItem item);
}
