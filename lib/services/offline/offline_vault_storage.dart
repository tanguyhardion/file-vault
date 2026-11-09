import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../cloud/cloud_auth.dart';
import '../cloud/cloud_client.dart';
import '../cloud/cloud_vaults.dart';
import '../storage/vault_storage.dart';
import '../vault_service.dart';
import 'local_vault_store.dart';
import 'sync_status.dart';

/// A vault's files, available offline.
///
/// Online, operations go to the server as before (so saving still detects an
/// edit made on another device) and the result is kept on this device.
/// Offline, they use and change the local copy, and [sync] sends the changes
/// once the server can be reached. Only ciphertext is stored or sent.
///
/// When syncing a file that was also changed on another device, the server's
/// version is kept and this device's version is uploaded next to it as
/// `<name> (conflict <date>)`, so no edit is lost.
class OfflineVaultStorage implements VaultStorage {
  final CloudVaultStorage remote;
  final LocalVaultStore _store;
  final SyncStatus _status;

  /// Called after the local copy changed; [localWrite] if it now has changes
  /// to send.
  final void Function({required bool localWrite}) _onChanged;

  Map<String, LocalFile>? _index;
  Future<void> _queue = Future.value();

  OfflineVaultStorage(this.remote, this._store, this._status, this._onChanged);

  String get vaultId => remote.vaultId;

  /// Files with changes the server doesn't have yet (0 until first used).
  int get pendingChanges => _index?.values.where((f) => f.isDirty).length ?? 0;

  /// Sends local changes, then updates the local copy from the server
  /// (downloading files that changed). Throws [CloudOfflineException].
  Future<void> sync() => _serial(() async {
    final index = await _load();
    try {
      await _push(index);
      await _pull(index);
    } finally {
      _onChanged(localWrite: false);
    }
    _status.markOnline();
  });

  @override
  Future<List<VaultItem>> listFiles() => _serial(() async {
    final index = await _load();
    if (_status.online) {
      try {
        await _push(index);
        await _pull(index);
        _status.markOnline();
      } on CloudOfflineException {
        _status.markOffline();
      } finally {
        _onChanged(localWrite: false);
      }
    }
    return [
      for (final f in index.values)
        if (!f.deleted) f.toItem(),
    ];
  });

  @override
  Future<VaultItem> stat(VaultItem item) => _serial(() async {
    final index = await _load();
    final online = await _online(index, () async {
      final f = index[item.id];
      // Local changes the server refused to take stay the current version.
      if (f != null && f.isDirty) return f.toItem();
      final VaultItem current;
      try {
        current = await remote.stat(item);
      } on FileMissingException {
        if (f != null) await _forget(index, f);
        rethrow;
      }
      (index[item.id] ??= LocalFile(
        id: item.id,
        name: current.name,
      )).adoptServer(current);
      await _save();
      return current;
    });
    if (online != null) return online.value;
    final f = index[item.id];
    if (f == null || f.deleted) throw FileMissingException(item.name);
    return f.toItem();
  });

  @override
  Future<Uint8List> read(VaultItem item) => _serial(() async {
    final index = await _load();
    final f = index[item.id];
    // The local copy is the version asked for: no download.
    if (f != null &&
        !f.deleted &&
        f.hasCurrentContent &&
        f.version == item.version) {
      final bytes = await _store.readContent(vaultId, f.id);
      if (bytes != null) return bytes;
    }
    if (_status.online) {
      try {
        final files = await remote.readMany([item.id]);
        _status.markOnline();
        if (files.isEmpty) throw FileMissingException(item.name);
        final file = files.single;
        if (f == null || !f.isDirty) {
          await _keepServerContent(index, file);
          await _save();
        }
        return file.content;
      } on CloudOfflineException {
        _status.markOffline();
      }
    }
    // Offline: the best local copy there is.
    if (f != null && !f.deleted) {
      final bytes = await _store.readContent(vaultId, f.id);
      if (bytes != null) return bytes;
    }
    throw const FileNotAvailableOfflineException();
  });

  @override
  Future<VaultItem> write(
    VaultItem item,
    Uint8List bytes, {
    String? ifVersion,
  }) => _serial(() async {
    final index = await _load();
    var expected = ifVersion;
    final known = index[item.id];
    // An editor opened this file offline and its edits were uploaded since:
    // its version is now the uploaded one.
    if (expected != null &&
        known != null &&
        !known.isDirty &&
        known.pushedFrom == expected) {
      expected = known.version;
    }
    final goOnline =
        (known == null || !known.isDirty) &&
        (expected == null || !LocalFile.isLocalVersion(expected));
    if (goOnline) {
      final online = await _online(index, () async {
        final written = await remote.write(item, bytes, ifVersion: expected);
        await _keepServerContent(index, RemoteFile(written, bytes));
        await _save();
        return written;
      });
      if (online != null) return online.value;
    }

    final f = index[item.id];
    if (f == null || f.deleted) throw FileMissingException(item.name);
    if (expected != null && expected != f.version) {
      throw FileChangedExternallyException();
    }
    await _store.writeContent(vaultId, f.id, bytes);
    f
      ..localEdits += 1
      ..size = bytes.length
      ..updatedAt = DateTime.now()
      ..pushedFrom = null;
    await _save();
    _onChanged(localWrite: true);
    return f.toItem();
  });

  @override
  Future<VaultItem> create(String name, Uint8List bytes) => _serial(() async {
    final index = await _load();
    _checkNameFree(index, name);
    // The same ID online and offline: if the upload went through but its
    // answer was lost, syncing recognizes the file.
    final id = _newId();
    final online = await _online(index, () async {
      final created = await remote.create(name, bytes, id: id);
      await _keepServerContent(index, RemoteFile(created, bytes));
      await _save();
      return created;
    });
    if (online != null) return online.value;

    final f = index[id] = LocalFile(
      id: id,
      name: name,
      localEdits: 1,
      size: bytes.length,
      updatedAt: DateTime.now(),
    );
    await _store.writeContent(vaultId, id, bytes);
    await _save();
    _onChanged(localWrite: true);
    return f.toItem();
  });

  @override
  Future<VaultItem> rename(VaultItem item, String newName) => _serial(() async {
    final index = await _load();
    final known = index[item.id];
    if (known != null && known.name == newName) return known.toItem();
    _checkNameFree(index, newName, except: item.id);
    if (known == null || !known.isDirty) {
      final online = await _online(index, () async {
        final renamed = await remote.rename(item, newName);
        (index[item.id] ??= LocalFile(
          id: item.id,
          name: renamed.name,
        )).adoptServer(renamed);
        await _save();
        return renamed;
      });
      if (online != null) return online.value;
    }

    final f = index[item.id];
    if (f == null || f.deleted) throw FileMissingException(item.name);
    f.name = newName;
    await _save();
    _onChanged(localWrite: true);
    return f.toItem();
  });

  @override
  Future<void> delete(VaultItem item) => _serial(() async {
    final index = await _load();
    final known = index[item.id];
    if (known == null || !known.isDirty) {
      final online = await _online(index, () async {
        await remote.delete(item);
        if (known != null) await _forget(index, known);
        return true;
      });
      if (online != null) return;
    }

    final f = index[item.id];
    if (f == null) return;
    if (f.serverVersion == null) {
      await _forget(index, f); // Never uploaded: nothing to tell the server.
    } else {
      f.deleted = true;
      await _save();
    }
    _onChanged(localWrite: true);
  });

  // --- Sync ---

  /// Runs [op] on the server, after sending pending changes. Returns null if
  /// the server can't be reached; the caller then works on the local copy.
  Future<_Online<T>?> _online<T>(
    Map<String, LocalFile> index,
    Future<T> Function() op,
  ) async {
    if (!_status.online) return null;
    try {
      await _push(index);
      final value = await op();
      _status.markOnline();
      return _Online(value);
    } on CloudOfflineException {
      _status.markOffline();
      return null;
    } finally {
      _onChanged(localWrite: false);
    }
  }

  Future<void> _push(Map<String, LocalFile> index) async {
    for (final f in index.values.where((f) => f.isDirty).toList()) {
      try {
        await _pushFile(index, f);
      } on CloudOfflineException {
        rethrow;
      } on NotSignedInException {
        rethrow;
      } catch (e) {
        // Keep the change and try again on the next sync.
        _status.reportError(e);
      }
      await _save();
    }
  }

  Future<void> _pushFile(Map<String, LocalFile> index, LocalFile f) async {
    final base = f.serverVersion;

    if (f.deleted) {
      if (base != null && !await remote.deleteIfVersion(f.id, '$base')) {
        final current = await remote.statById(f.id);
        if (current != null) {
          // Changed on another device since: keep that version.
          f.adoptServer(current);
          return;
        }
      }
      await _forget(index, f);
      return;
    }

    final content = (base == null || f.localEdits > 0)
        ? await _store.readContent(vaultId, f.id)
        : null;

    if (base == null) {
      _uploaded(f, await _insert(f.id, f.name, content!));
      return;
    }

    if (f.localEdits > 0) {
      final updated = await _update(
        f.id,
        content: content,
        name: f.name != f.serverName ? f.name : null,
        ifVersion: '$base',
      );
      if (updated != null) {
        _uploaded(f, updated);
        return;
      }
      final current = await remote.statById(f.id);
      if (current == null) {
        // Deleted on another device: the edit made here wins.
        _uploaded(f, await _insert(f.id, f.name, content!));
        return;
      }
      // Changed on another device too: keep both versions.
      final copy = await _insert(_newId(), _conflictName(f.name), content!);
      await _keepServerContent(index, RemoteFile(copy, content));
      f.adoptServer(current); // Its content is downloaded by _pull.
      return;
    }

    // Only renamed.
    final renamed = await _update(f.id, name: f.name);
    if (renamed == null) {
      await _forget(index, f); // Deleted on another device.
    } else {
      f.adoptServer(renamed);
    }
  }

  /// Mirrors the server's files, downloading new and changed content.
  Future<void> _pull(Map<String, LocalFile> index) async {
    final serverFiles = await remote.listFiles();
    final ids = <String>{};
    for (final item in serverFiles) {
      ids.add(item.id);
      final f = index[item.id];
      if (f == null) {
        index[item.id] = LocalFile(id: item.id, name: item.name)
          ..adoptServer(item);
      } else if (!f.isDirty) {
        f.adoptServer(item);
      }
    }
    // Deleted on another device.
    for (final f in index.values.toList()) {
      if (!f.isDirty && !ids.contains(f.id)) await _forget(index, f);
    }
    await _save();

    final stale = [
      for (final f in index.values)
        if (!f.isDirty && !f.hasCurrentContent) f.id,
    ];
    const batch = 50;
    for (var i = 0; i < stale.length; i += batch) {
      final files = await remote.readMany(
        stale.sublist(i, min(i + batch, stale.length)),
      );
      for (final file in files) {
        final f = index[file.item.id];
        if (f != null && !f.isDirty) await _keepServerContent(index, file);
      }
      await _save();
    }
  }

  /// Uploads a new file, renaming it if the name is taken.
  Future<VaultItem> _insert(String id, String name, Uint8List content) async {
    for (var n = 1; n <= _maxNameAttempts; n++) {
      final candidate = n == 1 ? name : _numbered(name, n);
      try {
        return await remote.create(candidate, content, id: id);
      } on NameConflictException {
        // Uploaded before, but the answer was lost? Then it's this file.
        if (await remote.statById(id) != null) {
          return (await remote.update(id, content: content))!;
        }
      }
    }
    throw NameConflictException(name);
  }

  /// [CloudVaultStorage.update], renaming if the new name is taken.
  Future<VaultItem?> _update(
    String id, {
    Uint8List? content,
    String? name,
    String? ifVersion,
  }) async {
    for (var n = 1; n <= _maxNameAttempts; n++) {
      final candidate = (name == null || n == 1) ? name : _numbered(name, n);
      try {
        return await remote.update(
          id,
          content: content,
          name: candidate,
          ifVersion: ifVersion,
        );
      } on NameConflictException {
        if (name == null) rethrow;
      }
    }
    throw NameConflictException(name!);
  }

  static const _maxNameAttempts = 100;

  void _uploaded(LocalFile f, VaultItem item) {
    final from = f.version;
    f.adoptServer(item);
    f
      ..contentVersion = f.serverVersion
      ..pushedFrom = from;
  }

  Future<void> _keepServerContent(
    Map<String, LocalFile> index,
    RemoteFile file,
  ) async {
    await _store.writeContent(vaultId, file.item.id, file.content);
    (index[file.item.id] ??= LocalFile(id: file.item.id, name: file.item.name))
      ..adoptServer(file.item)
      ..contentVersion = int.parse(file.item.version);
  }

  Future<void> _forget(Map<String, LocalFile> index, LocalFile f) async {
    index.remove(f.id);
    await _store.deleteContent(vaultId, f.id);
  }

  // --- Helpers ---

  Future<Map<String, LocalFile>> _load() async =>
      _index ??= await _store.readIndex(vaultId);

  Future<void> _save() async {
    final index = _index;
    if (index != null) await _store.writeIndex(vaultId, index.values);
  }

  /// Operations on the local copy run one at a time.
  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  static void _checkNameFree(
    Map<String, LocalFile> index,
    String name, {
    String? except,
  }) {
    if (index.values.any(
      (f) => !f.deleted && f.id != except && f.name == name,
    )) {
      throw NameConflictException(name);
    }
  }

  static String _withoutExtension(String name) =>
      name.replaceAll(RegExp(r'\.fva$', caseSensitive: false), '');

  /// "notes.fva" -> "notes (2).fva"
  static String _numbered(String name, int n) =>
      VaultService.fileNameFor('${_withoutExtension(name)} ($n)');

  /// "notes.fva" -> "notes (conflict 2026-11-10 14.05).fva"
  static String _conflictName(String name) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}.${two(now.minute)}';
    return VaultService.fileNameFor(
      '${_withoutExtension(name)} (conflict $stamp)',
    );
  }

  static final _random = Random.secure();

  /// Random (v4) UUID, the format of the database's IDs.
  static String _newId() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

class _Online<T> {
  final T value;
  const _Online(this.value);
}

/// The file has never been downloaded to this device and there is no
/// connection.
class FileNotAvailableOfflineException implements Exception {
  const FileNotAvailableOfflineException();

  @override
  String toString() =>
      "This file isn't on this device yet. Connect to download it.";
}
