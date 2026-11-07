import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:file_vault/mobile/onedrive/onedrive_auth.dart';
import 'package:file_vault/mobile/onedrive/onedrive_client.dart';
import 'package:file_vault/mobile/saved_vaults_store.dart';
import 'package:file_vault/mobile/storage/onedrive_vault_storage.dart';
import 'package:file_vault/mobile/storage/vault_storage.dart';
import 'package:file_vault/mobile/vault_session.dart';
import 'package:file_vault/services/vault_service.dart';
import 'package:file_vault/services/crypto_service.dart';

class _FakeAuth extends OneDriveAuth {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => 'token';
}

class _FakeItem {
  String name;
  final String parent;
  final bool isFolder;
  Uint8List bytes;
  int version = 1;

  _FakeItem(this.name, this.parent, {this.isFolder = false, Uint8List? bytes})
    : bytes = bytes ?? Uint8List(0);

  String get eTag => '"{$name},$version"';
}

/// In-memory stand-in for the Graph endpoints used by [OneDriveClient].
class _FakeOneDrive {
  final Map<String, _FakeItem> items = {};
  final List<http.Request> requests = [];
  int _nextId = 1;

  String add(_FakeItem item) {
    final id = 'id${_nextId++}';
    items[id] = item;
    return id;
  }

  Map<String, dynamic> _json(String id) {
    final item = items[id]!;
    return {
      'id': id,
      'name': item.name,
      'size': item.bytes.length,
      'eTag': item.eTag,
      'lastModifiedDateTime': '2026-01-01T00:00:00Z',
      if (item.isFolder) 'folder': {} else 'file': {},
    };
  }

  http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);

  Future<http.Response> handle(http.Request req) async {
    requests.add(req);
    if (req.url.host == 'download.example') {
      expect(req.headers.containsKey('Authorization'), isFalse);
      return http.Response.bytes(
        items[req.url.pathSegments.single]!.bytes,
        200,
      );
    }
    expect(req.headers['Authorization'], 'Bearer token');

    final path = req.url.path.replaceFirst('/v1.0/me/drive/items/', '');
    final create = RegExp(r'^([^:/]+):/(.+):/content$').firstMatch(path);
    if (create != null && req.method == 'PUT') {
      final parent = create.group(1)!;
      final name = Uri.decodeComponent(create.group(2)!);
      if (items.values.any((i) => i.parent == parent && i.name == name)) {
        return http.Response('{}', 409);
      }
      return _ok(_json(add(_FakeItem(name, parent, bytes: req.bodyBytes))));
    }

    final segments = path.split('/');
    final id = segments.first;
    final sub = segments.length > 1 ? segments[1] : '';
    switch ((req.method, sub)) {
      case ('GET', 'children'):
        final ids = items.keys.where((k) => items[k]!.parent == id);
        return _ok({'value': ids.map(_json).toList()});
      case ('GET', ''):
        return _ok(_json(id));
      case ('GET', 'content'):
        return http.Response(
          '',
          302,
          headers: {'location': 'https://download.example/$id'},
        );
      case ('PUT', 'content'):
        final item = items[id]!;
        final ifMatch = req.headers['If-Match'];
        if (ifMatch != null && ifMatch != item.eTag) {
          return http.Response('{}', 412);
        }
        item
          ..bytes = req.bodyBytes
          ..version += 1;
        return _ok(_json(id));
      case ('PATCH', ''):
        items[id]!.name = (jsonDecode(req.body) as Map)['name'] as String;
        return _ok(_json(id));
      case ('DELETE', ''):
        items.remove(id);
        return http.Response('', 204);
    }
    return http.Response('{}', 404);
  }
}

void main() {
  const password = 'correct horse';
  late _FakeOneDrive drive;
  late OneDriveVaultStorage storage;
  late SavedVault vault;
  late String noteId;

  setUp(() async {
    drive = _FakeOneDrive();
    final client = OneDriveClient(
      _FakeAuth(),
      httpClient: MockClient(drive.handle),
    );

    final folderId = drive.add(_FakeItem('Vault', 'root', isFolder: true));
    final salt = CryptoService.randomSalt();
    final hash = await CryptoService.hashPassword(
      password: password,
      salt: salt,
    );
    drive.add(
      _FakeItem(
        '.vault_marker',
        folderId,
        bytes: utf8.encode(
          'vault_version: 1\nsalt: ${base64Encode(salt)}\n'
          'password_hash: ${base64Encode(hash)}\n',
        ),
      ),
    );
    noteId = drive.add(
      _FakeItem(
        'note.fva',
        folderId,
        bytes: await CryptoService.encryptString(
          content: 'secret text',
          password: password,
        ),
      ),
    );
    storage = OneDriveVaultStorage(client, folderId);
    vault = SavedVault(
      location: VaultLocation.oneDrive,
      id: folderId,
      name: 'Vault',
      path: '/Vault',
    );
  });

  test('rejects a wrong password', () async {
    expect(
      VaultSession.unlock(storage, vault, 'nope'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('lists only .fva files and decrypts content', () async {
    final session = await VaultSession.unlock(storage, vault, password);
    expect(session.files.map((f) => f.name), ['note.fva']);

    final opened = await session.openFile(session.files.single);
    expect(opened.content, 'secret text');
  });

  test('uploads only ciphertext, conditioned on the opened eTag', () async {
    final session = await VaultSession.unlock(storage, vault, password);
    final opened = await session.openFile(session.files.single);

    await session.save(opened, 'edited on phone');

    final put = drive.requests.lastWhere((r) => r.method == 'PUT');
    expect(put.headers['If-Match'], opened.item.version);
    expect(utf8.decode(put.bodyBytes.sublist(0, 4)), 'FVA1');
    expect(latin1.decode(put.bodyBytes), isNot(contains('edited on phone')));
    expect(
      await CryptoService.decryptToString(
        data: drive.items[noteId]!.bytes,
        password: password,
      ),
      'edited on phone',
    );
  });

  test('detects a change made on another device', () async {
    final session = await VaultSession.unlock(storage, vault, password);
    final opened = await session.openFile(session.files.single);

    // Another device saves in the meantime.
    drive.items[noteId]!.version += 1;

    expect(
      session.save(opened, 'stale edit'),
      throwsA(isA<FileChangedExternallyException>()),
    );
  });

  test('overwrite skips the eTag check', () async {
    final session = await VaultSession.unlock(storage, vault, password);
    final opened = await session.openFile(session.files.single);
    drive.items[noteId]!.version += 1;

    await session.save(opened, 'forced', overwrite: true);

    final put = drive.requests.lastWhere((r) => r.method == 'PUT');
    expect(put.headers.containsKey('If-Match'), isFalse);
  });

  test('creates encrypted files and refuses duplicates', () async {
    final session = await VaultSession.unlock(storage, vault, password);

    final created = await session.createFile('todo');
    expect(created.item.name, 'todo.fva');
    expect(session.files.map((f) => f.name), ['note.fva', 'todo.fva']);
    expect(session.createFile('note'), throwsA(isA<NameConflictException>()));
  });

  test('lock clears the session', () async {
    final session = await VaultSession.unlock(storage, vault, password);
    session.lock();
    expect(session.isLocked, isTrue);
    expect(session.files, isEmpty);
  });
}
