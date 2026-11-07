import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:file_vault/mobile/saved_vaults_store.dart';
import 'package:file_vault/mobile/storage/local_vault_storage.dart';
import 'package:file_vault/mobile/storage/vault_storage.dart';
import 'package:file_vault/mobile/vault_session.dart';
import 'package:file_vault/services/crypto_service.dart';
import 'package:file_vault/services/vault_service.dart';

void main() {
  const password = 'correct horse';
  late Directory dir;
  late LocalVaultStorage storage;
  late SavedVault vault;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vault_test');
    final salt = CryptoService.randomSalt();
    final hash = await CryptoService.hashPassword(
      password: password,
      salt: salt,
    );
    await File(p.join(dir.path, '.vault_marker')).writeAsString(
      'vault_version: 1\nsalt: ${base64Encode(salt)}\n'
      'password_hash: ${base64Encode(hash)}\n',
    );
    await File(p.join(dir.path, 'note.fva')).writeAsBytes(
      await CryptoService.encryptString(
        content: 'secret text',
        password: password,
      ),
    );
    // Not vault files: must not be listed.
    await File(p.join(dir.path, '.syncthing.note.fva.tmp')).writeAsString('x');
    await Directory(p.join(dir.path, '.stfolder')).create();

    storage = LocalVaultStorage(dir.path);
    vault = SavedVault(
      location: VaultLocation.local,
      id: dir.path,
      name: 'Vault',
      path: dir.path,
    );
  });

  tearDown(() => dir.delete(recursive: true));

  test('rejects a wrong password', () async {
    expect(
      VaultSession.unlock(storage, vault, 'nope'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('reports a missing vault folder', () async {
    expect(
      VaultSession.unlock(
        LocalVaultStorage(p.join(dir.path, 'gone')),
        vault,
        password,
      ),
      throwsA(isA<VaultFolderMissingException>()),
    );
  });

  test('lists only .fva files and saves only ciphertext', () async {
    final session = await VaultSession.unlock(storage, vault, password);
    expect(session.files.map((f) => f.name), ['note.fva']);

    final opened = await session.openFile(session.files.single);
    expect(opened.content, 'secret text');

    await session.save(opened, 'edited on phone');
    final bytes = await File(p.join(dir.path, 'note.fva')).readAsBytes();
    expect(utf8.decode(bytes.sublist(0, 4)), 'FVA1');
    expect(latin1.decode(bytes), isNot(contains('edited on phone')));
    expect(
      await CryptoService.decryptToString(data: bytes, password: password),
      'edited on phone',
    );
  });

  test('refuses to overwrite a file synced in meanwhile', () async {
    final session = await VaultSession.unlock(storage, vault, password);
    final opened = await session.openFile(session.files.single);

    // Syncthing writes a newer version from the PC.
    await File(p.join(dir.path, 'note.fva')).writeAsBytes(
      await CryptoService.encryptString(
        content: 'edited on PC',
        password: password,
      ),
    );

    await expectLater(
      session.save(opened, 'stale edit'),
      throwsA(isA<FileChangedExternallyException>()),
    );
    await session.save(opened, 'forced', overwrite: true);
    final reopened = await session.openFile(session.files.single);
    expect(reopened.content, 'forced');
  });

  test('creates, renames and deletes files', () async {
    final session = await VaultSession.unlock(storage, vault, password);

    final created = await session.createFile('todo');
    expect(session.files.map((f) => f.name), ['note.fva', 'todo.fva']);
    await expectLater(
      session.createFile('note'),
      throwsA(isA<NameConflictException>()),
    );
    await expectLater(
      session.renameFile(created.item, 'note'),
      throwsA(isA<NameConflictException>()),
    );

    final renamed = await session.renameFile(created.item, 'later');
    expect(session.files.map((f) => f.name), ['later.fva', 'note.fva']);

    await session.deleteFile(renamed);
    expect(session.files.map((f) => f.name), ['note.fva']);
    expect(await File(p.join(dir.path, 'later.fva')).exists(), isFalse);
  });
}
