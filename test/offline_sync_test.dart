import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:file_vault/services/cloud/cloud_auth.dart';
import 'package:file_vault/services/cloud/cloud_client.dart';
import 'package:file_vault/services/cloud/cloud_vaults.dart';
import 'package:file_vault/services/offline/vault_repository.dart';
import 'package:file_vault/services/storage/vault_storage.dart';
import 'package:file_vault/services/vault_session.dart';

import 'fake_supabase.dart';

void main() {
  const pw = 'vault-pw';
  late FakeSupabase server;
  late CloudAuth auth;
  late Directory dir;
  late VaultRepository app;
  late CloudVault vault;

  /// Another device, with its own connection to the server.
  Future<VaultSession> otherDevice() async {
    final phone = server.auth(otherDevice: true);
    await phone.init();
    await phone.signIn('me@example.com', 'account-pw');
    return VaultSession.unlock(
      server.repository(phone, otherDevice: true).storageFor(vault),
      vault,
      pw,
    );
  }

  Future<String> serverContent(String name) async {
    final other = await otherDevice();
    final file = other.files.firstWhere((f) => f.name == name);
    return (await other.openFile(file)).content;
  }

  Future<VaultSession> unlockHere() =>
      VaultSession.unlock(app.storageFor(vault), vault, pw);

  /// The app restarting, with the same offline copy.
  VaultRepository restart() {
    app.dispose();
    return app = server.offlineRepository(auth, dir);
  }

  setUp(() async {
    server = FakeSupabase()..users['me@example.com'] = 'account-pw';
    auth = server.auth();
    await auth.init();
    await auth.signIn('me@example.com', 'account-pw');
    dir = await Directory.systemTemp.createTemp('file_vault_offline');
    app = server.offlineRepository(auth, dir);

    vault = await app.create('Personal', pw);
    final session = await unlockHere();
    final note = await session.createFile('Note');
    await session.save(note, 'v1');
    await app.syncAll();
  });

  tearDown(() async {
    app.dispose();
    await dir.delete(recursive: true);
  });

  test('vaults open and read offline after a restart', () async {
    server.offline = true;
    restart();

    final vaults = await app.list();
    expect(vaults.map((v) => v.name), ['Personal']);
    expect(app.status.online, isFalse);

    final session = await unlockHere();
    expect(session.files.map((f) => f.name), ['Note.fva']);
    expect((await session.openFile(session.files.single)).content, 'v1');
  });

  test('the wrong password is still refused offline', () async {
    server.offline = true;
    restart();
    final cached = (await app.list()).single;
    await expectLater(
      VaultSession.unlock(app.storageFor(cached), cached, 'nope'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test(
    'without an offline copy, listing vaults reports being offline',
    () async {
      await dir.delete(recursive: true);
      server.offline = true;
      restart();
      await expectLater(app.list(), throwsA(isA<CloudOfflineException>()));
      await dir.create();
    },
  );

  test('offline edits are sent when back online', () async {
    final session = await unlockHere();
    server.offline = true;

    var opened = await session.openFile(session.files.single);
    opened = await session.save(opened, 'offline 1');
    opened = await session.save(opened, 'offline 2');
    expect(app.status.pendingChanges, 1);
    expect(app.status.online, isFalse);

    server.offline = false;
    await app.syncAll();
    expect(app.status.pendingChanges, 0);
    expect(app.status.online, isTrue);
    expect(await serverContent('Note.fva'), 'offline 2');

    // The editor that saved offline keeps saving normally.
    opened = await session.save(opened, 'online again');
    expect(await serverContent('Note.fva'), 'online again');
  });

  test('files created, renamed and deleted offline are synced', () async {
    final session = await unlockHere();
    server.offline = true;

    final todo = await session.createFile('Todo');
    await session.save(todo, 'buy milk');
    final note = session.files.firstWhere((f) => f.name == 'Note.fva');
    await session.renameFile(note, 'Journal');
    final scratch = await session.createFile('Scratch');
    await session.deleteFile(scratch.item); // Never reaches the server.
    expect(session.files.map((f) => f.name), ['Journal.fva', 'Todo.fva']);

    server.offline = false;
    await app.syncAll();
    expect(server.files.map((f) => f['name']).toList()..sort(), [
      'Journal.fva',
      'Todo.fva',
    ]);
    expect(await serverContent('Todo.fva'), 'buy milk');
    expect(await serverContent('Journal.fva'), 'v1');

    server.offline = true;
    final journal = session.files.firstWhere((f) => f.name == 'Journal.fva');
    await session.deleteFile(journal);
    server.offline = false;
    await app.syncAll();
    expect(server.files.map((f) => f['name']), ['Todo.fva']);
  });

  test(
    'changes made on another device are downloaded for offline use',
    () async {
      final other = await otherDevice();
      final added = await other.createFile('From phone');
      await other.save(added, 'hello');
      final note = await other.openFile(
        other.files.firstWhere((f) => f.name == 'Note.fva'),
      );
      await other.save(note, 'v2 from phone');

      await app.syncAll();
      server.offline = true;
      restart();
      final session = await unlockHere();
      final byName = {for (final f in session.files) f.name: f};
      expect(
        (await session.openFile(byName['From phone.fva']!)).content,
        'hello',
      );
      expect(
        (await session.openFile(byName['Note.fva']!)).content,
        'v2 from phone',
      );
    },
  );

  test(
    'an offline edit to a file changed elsewhere keeps both versions',
    () async {
      final session = await unlockHere();
      server.offline = true;
      final opened = await session.openFile(session.files.single);
      await session.save(opened, 'edited offline');

      final other = await otherDevice();
      await other.save(
        await other.openFile(other.files.single),
        'edited on phone',
      );

      server.offline = false;
      await app.syncAll();
      expect(app.status.pendingChanges, 0);
      expect(await serverContent('Note.fva'), 'edited on phone');
      final copy = server.files
          .map((f) => f['name'] as String)
          .singleWhere((n) => n.startsWith('Note (conflict '));
      expect(copy, endsWith('.fva'));
      expect(await serverContent(copy), 'edited offline');

      // This device now shows the server's version, and the copy.
      await session.refresh();
      expect(session.files, hasLength(2));
      final note = session.files.firstWhere((f) => f.name == 'Note.fva');
      expect((await session.openFile(note)).content, 'edited on phone');
    },
  );

  test(
    'the editor is told when its offline edit lost to another device',
    () async {
      final session = await unlockHere();
      server.offline = true;
      var opened = await session.openFile(session.files.single);
      opened = await session.save(opened, 'edited offline');

      final other = await otherDevice();
      await other.save(await other.openFile(other.files.single), 'phone');
      server.offline = false;
      await app.syncAll();

      await expectLater(
        session.save(opened, 'more offline edits'),
        throwsA(isA<FileChangedExternallyException>()),
      );
    },
  );

  test('a file edited offline but deleted elsewhere is kept', () async {
    final session = await unlockHere();
    server.offline = true;
    await session.save(
      await session.openFile(session.files.single),
      'still needed',
    );

    final other = await otherDevice();
    await other.deleteFile(other.files.single);
    server.offline = false;
    await app.syncAll();
    expect(await serverContent('Note.fva'), 'still needed');
  });

  test('a file deleted offline but edited elsewhere is kept', () async {
    final session = await unlockHere();
    server.offline = true;
    await session.deleteFile(session.files.single);

    final other = await otherDevice();
    await other.save(await other.openFile(other.files.single), 'phone edit');
    server.offline = false;
    await app.syncAll();

    expect(await serverContent('Note.fva'), 'phone edit');
    await session.refresh();
    expect(session.files.map((f) => f.name), ['Note.fva']);
  });

  test('a name taken on the server while offline gets a number', () async {
    final session = await unlockHere();
    server.offline = true;
    final mine = await session.createFile('Ideas');
    await session.save(mine, 'mine');

    final other = await otherDevice();
    await other.save(await other.createFile('Ideas'), 'theirs');
    server.offline = false;
    await app.syncAll();

    expect(await serverContent('Ideas.fva'), 'theirs');
    expect(await serverContent('Ideas (2).fva'), 'mine');
  });

  test('online saves still detect an edit made on another device', () async {
    final session = await unlockHere();
    final opened = await session.openFile(session.files.single);
    final other = await otherDevice();
    await other.save(await other.openFile(other.files.single), 'phone');
    await expectLater(
      session.save(opened, 'stale'),
      throwsA(isA<FileChangedExternallyException>()),
    );
  });

  test('opening a cached file does not download it again', () async {
    final session = await unlockHere();
    final before = server.requests;
    await session.openFile(session.files.single);
    // Only the version check; the content comes from this device.
    expect(server.requests - before, 1);
  });

  test('vault changes need a connection', () async {
    server.offline = true;
    await expectLater(
      app.create('Work', pw),
      throwsA(isA<CloudOfflineException>()),
    );
  });

  test('signing out removes the offline copy', () async {
    expect(await app.syncBeforeSignOut(), 0);
    await app.deleteLocalCopy();
    expect(await dir.exists(), isFalse);
    await dir.create(); // For tearDown.
  });
}
