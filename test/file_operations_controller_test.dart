import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:file_vault/controllers/file_operations_controller.dart';
import 'package:file_vault/controllers/vault_controller.dart';
import 'package:file_vault/services/crypto_worker.dart';
import 'package:file_vault/services/vault_service.dart';

void main() {
  const password = 'pw';
  late Directory dir;
  late VaultController vault;
  late FileOperationsController ops;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('file_vault_test');
    vault = VaultController();
    final entry = await VaultService.writeVaultFileBytes(
      dirPath: dir.path,
      fileNameWithoutExt: 'note',
      encryptedBytes: await CryptoWorker.encryptString(
        content: 'original',
        password: password,
      ),
    );
    vault.setVaultOpen(dir.path, password, [entry]);
    ops = FileOperationsController(vault);
    await ops.openFile(entry);
  });

  tearDown(() => dir.delete(recursive: true));

  test('saves normally when the file is unchanged on disk', () async {
    await ops.saveCurrentFile('edited');
    await ops.saveCurrentFile('edited again');
    expect(ops.dirty, isFalse);
  });

  test('refuses to save over a file synced from another device', () async {
    final path = ops.openedContent!.source.fullPath;
    // Simulate OneDrive syncing down a newer version.
    await VaultService.overwriteVaultFileBytes(
      fullPath: path,
      encryptedBytes: await CryptoWorker.encryptString(
        content: 'from phone, a bit longer',
        password: password,
      ),
    );

    await expectLater(
      ops.saveCurrentFile('stale desktop edit'),
      throwsA(isA<FileChangedExternallyException>()),
    );
    expect(ops.loading, isFalse);

    await ops.saveCurrentFile('stale desktop edit', overwrite: true);
    final bytes = await VaultService.readVaultFileBytes(path);
    expect(
      await CryptoWorker.decryptToString(data: bytes, password: password),
      'stale desktop edit',
    );
  });
}
