import 'dart:typed_data';

import 'package:file_vault/services/crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encrypt/decrypt empty string roundtrip', () async {
    const password = 'test-pass';
    final bytes = await CryptoService.encryptString(
      content: '',
      password: password,
    );
    expect(bytes.length, greaterThan(0));

    final decrypted = await CryptoService.decryptToString(
      data: Uint8List.fromList(bytes),
      password: password,
    );
    expect(decrypted, '');
  });
}
