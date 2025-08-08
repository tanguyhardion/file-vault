import 'dart:io';

import 'package:file_vault/models/vault_models.dart';
import 'package:file_vault/services/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('vault save/load roundtrip', () async {
    final service = VaultService();
    final entries = <VaultEntry>[
      VaultEntry(path: 'hello.txt', data: 'hello world'.codeUnits),
      VaultEntry(path: 'folder/nested.bin', data: List<int>.generate(256, (i) => i % 256)),
    ];
    final tempDir = await Directory.systemTemp.createTemp('file_vault_test_');
    final vaultPath = p.join(tempDir.path, 'test.fva');

    const password = 'P@ssw0rd!';

    await service.saveVault(vaultPath: vaultPath, entries: entries, password: password);

    final loaded = await service.loadVault(vaultPath: vaultPath, password: password);

    expect(loaded.length, entries.length);
    for (int i = 0; i < entries.length; i++) {
      expect(loaded[i].path, entries[i].path);
      expect(loaded[i].data, entries[i].data);
    }

    await tempDir.delete(recursive: true);
  });
}
