import 'dart:typed_data';

import '../onedrive/onedrive_client.dart';
import 'vault_storage.dart';

/// A vault folder in OneDrive, accessed through Microsoft Graph.
class OneDriveVaultStorage implements VaultStorage {
  final OneDriveClient _client;
  final String folderId;

  const OneDriveVaultStorage(this._client, this.folderId);

  @override
  Future<List<VaultItem>> listFiles() async {
    try {
      final children = await _client.listChildren(folderId);
      return children.where((c) => !c.isFolder).map(_item).toList();
    } on OneDriveException catch (e) {
      if (e.isNotFound) throw VaultFolderMissingException();
      rethrow;
    }
  }

  @override
  Future<VaultItem> stat(VaultItem item) async =>
      _item(await _client.getItem(item.id));

  @override
  Future<Uint8List> read(VaultItem item) => _client.download(item.id);

  @override
  Future<VaultItem> write(
    VaultItem item,
    Uint8List bytes, {
    String? ifVersion,
  }) async =>
      _item(await _client.replaceContent(item.id, bytes, ifMatchETag: ifVersion));

  @override
  Future<VaultItem> create(String name, Uint8List bytes) async =>
      _item(await _client.createFile(folderId, name, bytes));

  @override
  Future<VaultItem> rename(VaultItem item, String newName) async =>
      _item(await _client.rename(item.id, newName));

  @override
  Future<void> delete(VaultItem item) => _client.delete(item.id);

  static VaultItem _item(DriveItem d) => VaultItem(
    id: d.id,
    name: d.name,
    size: d.size,
    lastModified: d.lastModified,
    version: d.eTag,
  );
}
