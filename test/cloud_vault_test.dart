import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:file_vault/services/cloud/cloud_auth.dart';
import 'package:file_vault/services/cloud/cloud_vaults.dart';
import 'package:file_vault/services/storage/vault_storage.dart';
import 'package:file_vault/services/vault_archive.dart';
import 'package:file_vault/services/vault_marker.dart';
import 'package:file_vault/services/vault_session.dart';

import 'fake_supabase.dart';

void main() {
  late FakeSupabase server;
  late CloudAuth auth;
  late CloudVaultRepository repo;

  setUp(() async {
    server = FakeSupabase()..users['me@example.com'] = 'account-pw';
    auth = server.auth();
    await auth.init();
    await auth.signIn('me@example.com', 'account-pw');
    repo = server.repository(auth);
  });

  group('CloudAuth', () {
    test('rejects a wrong account password', () async {
      final other = server.auth();
      await other.init();
      await expectLater(
        other.signIn('me@example.com', 'nope'),
        throwsA(
          isA<CloudAuthException>().having(
            (e) => e.message,
            'message',
            'Invalid login credentials',
          ),
        ),
      );
      expect(other.isSignedIn, isFalse);
    });

    test('restores the session on another launch', () async {
      final store = MemoryTokenStore();
      final first = server.auth(store: store);
      await first.init();
      await first.signIn('me@example.com', 'account-pw');

      final second = server.auth(store: store);
      await second.init();
      expect(second.isSignedIn, isTrue);
      expect(second.email, 'me@example.com');
      // No access token in memory yet: it is obtained with the refresh token.
      expect(await second.accessToken(), startsWith('at-'));
      expect(store.values['cloud_refresh_token'], isNot(isEmpty));
    });

    test('sign up may require email confirmation', () async {
      server.requireEmailConfirmation = true;
      final a = server.auth();
      await a.init();
      expect(await a.signUp('new@example.com', 'password1'), isFalse);
      expect(a.isSignedIn, isFalse);
    });

    test('refreshes an expired access token and retries', () async {
      await repo.create('Personal', 'vault-pw');
      server.expireAccessTokens();
      expect((await repo.list()).single.name, 'Personal');
    });

    test('a revoked session signs out', () async {
      final store = MemoryTokenStore()
        ..values['cloud_refresh_token'] = 'revoked';
      final a = server.auth(store: store);
      await a.init();
      await expectLater(a.accessToken(), throwsA(isA<NotSignedInException>()));
      expect(a.isSignedIn, isFalse);
    });
  });

  group('vaults', () {
    test('creates, lists and refuses duplicate names', () async {
      final vault = await repo.create('Personal', 'vault-pw');
      expect(vault.name, 'Personal');
      expect(await vault.marker.verifyPassword('vault-pw'), isTrue);
      expect(
        server.vaults.single['password_hash'],
        isNot(contains('vault-pw')),
      );

      await expectLater(
        repo.create('Personal', 'x'),
        throwsA(isA<VaultNameTakenException>()),
      );
      expect((await repo.list()).map((v) => v.name), ['Personal']);
    });

    test('other accounts see nothing', () async {
      await repo.create('Personal', 'vault-pw');
      server.users['other@example.com'] = 'pw';
      final other = server.auth();
      await other.init();
      await other.signIn('other@example.com', 'pw');
      expect(await server.repository(other).list(), isEmpty);
    });

    test('auto backup setting is stored on the vault', () async {
      final vault = await repo.create('Personal', 'vault-pw');
      await repo.setAutoBackupEnabled(vault, true);
      expect((await repo.list()).single.autoBackupEnabled, isTrue);
    });
  });

  group('VaultSession on the database', () {
    late CloudVault vault;

    setUp(() async {
      vault = await repo.create('Personal', 'vault-pw');
    });

    Future<VaultSession> unlock() =>
        VaultSession.unlock(repo.storageFor(vault), vault, 'vault-pw');

    test('wrong vault password is refused', () async {
      await expectLater(
        VaultSession.unlock(repo.storageFor(vault), vault, 'wrong'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('stores only ciphertext and round-trips content', () async {
      final session = await unlock();
      final created = await session.createFile('Bank');
      expect(created.item.name, 'Bank.fva');
      await session.save(created, 'PIN 1234');

      final stored = server.files.single['content'] as String;
      expect(
        utf8.decode(base64Decode(stored), allowMalformed: true),
        isNot(contains('PIN 1234')),
      );

      // Another device sees it.
      final phone = await unlock();
      expect(phone.files.map((f) => f.name), ['Bank.fva']);
      expect((await phone.openFile(phone.files.single)).content, 'PIN 1234');
    });

    test('detects an edit made on another device', () async {
      final pc = await unlock();
      final openedOnPc = await pc.openFile((await pc.createFile('Note')).item);

      final phone = await unlock();
      final openedOnPhone = await phone.openFile(phone.files.single);
      await phone.save(openedOnPhone, 'from phone');

      await expectLater(
        pc.save(openedOnPc, 'stale pc edit'),
        throwsA(isA<FileChangedExternallyException>()),
      );
      final forced = await pc.save(openedOnPc, 'pc wins', overwrite: true);
      expect((await phone.openFile(forced.item)).content, 'pc wins');
    });

    test('rename and delete', () async {
      final session = await unlock();
      final a = await session.createFile('A');
      await session.createFile('B');
      await expectLater(
        session.renameFile(a.item, 'B'),
        throwsA(isA<NameConflictException>()),
      );
      final renamed = await session.renameFile(a.item, 'C');
      expect(session.files.map((f) => f.name), ['B.fva', 'C.fva']);
      await session.deleteFile(renamed);
      expect(session.files.map((f) => f.name), ['B.fva']);
      expect(server.files, hasLength(1));
    });
  });

  group('VaultArchive', () {
    test('backup ZIP imports back as the same vault', () async {
      final vault = await repo.create('Personal', 'vault-pw');
      final session = await VaultSession.unlock(
        repo.storageFor(vault),
        vault,
        'vault-pw',
      );
      final note = await session.createFile('Note');
      await session.save(note, 'secret text');

      final zip = await VaultArchive.buildBackupZip(vault, session.storage);
      final entries = VaultArchive.readZip(zip);
      expect(entries.keys, containsAll([VaultMarker.fileName, 'Note.fva']));

      final restored = await VaultArchive.import(repo, 'Restored', entries);
      final restoredSession = await VaultSession.unlock(
        repo.storageFor(restored),
        restored,
        'vault-pw',
      );
      final opened = await restoredSession.openFile(
        restoredSession.files.single,
      );
      expect(opened.content, 'secret text');
    });

    test('imports a legacy vault folder layout', () async {
      final marker = await VaultMarker.create('old-pw');
      final files = <String, Uint8List>{
        VaultMarker.fileName: utf8.encode(
          marker.toFileContents(autoBackupEnabled: true),
        ),
        'a.fva': Uint8List.fromList([1, 2, 3]),
        'desktop.ini': Uint8List.fromList([0]),
      };
      final vault = await VaultArchive.import(repo, 'Old', files);
      expect(vault.autoBackupEnabled, isTrue);
      expect(await vault.marker.verifyPassword('old-pw'), isTrue);
      final items = await repo.storageFor(vault).listFiles();
      expect(items.map((i) => i.name), ['a.fva']);
    });

    test('refuses a folder without a marker and keeps nothing', () async {
      await expectLater(
        VaultArchive.import(repo, 'X', {'a.fva': Uint8List(1)}),
        throwsA(isA<NotAVaultException>()),
      );
      expect(server.vaults, isEmpty);
    });
  });
}
