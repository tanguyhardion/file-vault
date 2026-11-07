import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../services/vault_service.dart';
import 'vault_storage.dart';

/// A vault folder on the phone's storage, e.g. one kept in sync by Syncthing.
class LocalVaultStorage implements VaultStorage {
  final String dirPath;

  const LocalVaultStorage(this.dirPath);

  @override
  Future<List<VaultItem>> listFiles() async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) throw VaultFolderMissingException();
    final items = <VaultItem>[];
    await for (final ent in dir.list(followLinks: false)) {
      if (ent is File) items.add(await _item(ent));
    }
    return items;
  }

  @override
  Future<VaultItem> stat(VaultItem item) => _item(File(item.id));

  @override
  Future<Uint8List> read(VaultItem item) => File(item.id).readAsBytes();

  @override
  Future<VaultItem> write(
    VaultItem item,
    Uint8List bytes, {
    String? ifVersion,
  }) async {
    final file = File(item.id);
    if (ifVersion != null &&
        (!await file.exists() || (await _item(file)).version != ifVersion)) {
      throw FileChangedExternallyException();
    }
    await file.writeAsBytes(bytes, flush: true);
    return _item(file);
  }

  @override
  Future<VaultItem> create(String name, Uint8List bytes) async {
    final file = File(p.join(dirPath, name));
    try {
      await file.create(exclusive: true);
    } on PathExistsException {
      throw NameConflictException(name);
    }
    await file.writeAsBytes(bytes, flush: true);
    return _item(file);
  }

  @override
  Future<VaultItem> rename(VaultItem item, String newName) async {
    final target = p.join(dirPath, newName);
    if (p.equals(item.id, target)) return stat(item);
    if (await File(target).exists()) throw NameConflictException(newName);
    return _item(await File(item.id).rename(target));
  }

  @override
  Future<void> delete(VaultItem item) async {
    final file = File(item.id);
    if (await file.exists()) await file.delete();
  }

  static Future<VaultItem> _item(File file) async {
    final stat = await file.stat();
    if (stat.type == FileSystemEntityType.notFound) {
      throw FileSystemException('File does not exist', file.path);
    }
    return VaultItem(
      id: file.absolute.path,
      name: p.basename(file.path),
      size: stat.size,
      lastModified: stat.modified,
      version: '${stat.size}:${stat.modified.microsecondsSinceEpoch}',
    );
  }
}
