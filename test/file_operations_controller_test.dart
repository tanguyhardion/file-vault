import 'package:flutter_test/flutter_test.dart';

import 'package:file_vault/controllers/file_operations_controller.dart';
import 'package:file_vault/controllers/vault_controller.dart';
import 'package:file_vault/services/cloud/cloud_vaults.dart';
import 'package:file_vault/services/storage/vault_storage.dart';
import 'package:file_vault/services/vault_session.dart';

import 'fake_supabase.dart';

void main() {
  const password = 'pw';
  late CloudVaultRepository repo;
  late CloudVault cloudVault;
  late VaultController vault;
  late FileOperationsController ops;

  setUp(() async {
    final server = FakeSupabase()..users['me@example.com'] = 'account';
    final auth = server.auth();
    await auth.init();
    await auth.signIn('me@example.com', 'account');
    repo = server.repository(auth);
    vault = VaultController(repo);
    cloudVault = await vault.createVault('Personal', password);
    ops = FileOperationsController(vault);
    await ops.createNewFile('note');
    await ops.saveCurrentFile('original');
  });

  test('saves normally when the file is unchanged', () async {
    await ops.saveCurrentFile('edited');
    await ops.saveCurrentFile('edited again');
    expect(ops.dirty, isFalse);
  });

  test('refuses to save over a file edited on another device', () async {
    final phone = await VaultSession.unlock(
      repo.storageFor(cloudVault),
      cloudVault,
      password,
    );
    final onPhone = await phone.openFile(phone.files.single);
    await phone.save(onPhone, 'from phone, a bit longer');

    await expectLater(
      ops.saveCurrentFile('stale desktop edit'),
      throwsA(isA<FileChangedExternallyException>()),
    );
    expect(ops.loading, isFalse);

    await ops.saveCurrentFile('stale desktop edit', overwrite: true);
    expect(
      (await phone.openFile(phone.files.single)).content,
      'stale desktop edit',
    );
  });
}
