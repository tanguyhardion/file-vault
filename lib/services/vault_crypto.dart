import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class VaultCrypto {
  // KDF parameters
  static const int pbkdf2Iterations = 150000; // reasonable desktop default
  static const int saltLength = 16;
  static const int nonceLength = 12; // for AES-GCM

  // Derive a 256-bit key from password+salt
  static Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  // Encrypt bytes with password; returns: salt(16) | nonce(12) | ciphertext | tag(16)
  static Future<Uint8List> encrypt(List<int> plaintext, String password) async {
    final algorithm = AesGcm.with256bits();
    final salt = SecretKeyData.random(length: saltLength).bytes;
    final key = await _deriveKey(password, salt);
    final nonce = algorithm.newNonce();

    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );

    final out = Uint8List(saltLength + nonceLength + secretBox.cipherText.length + secretBox.mac.bytes.length);
    out.setAll(0, salt);
    out.setAll(saltLength, nonce);
    out.setAll(saltLength + nonceLength, secretBox.cipherText);
    out.setAll(saltLength + nonceLength + secretBox.cipherText.length, secretBox.mac.bytes);
    return out;
  }

  // Decrypt bytes from salt|nonce|ciphertext|tag using password
  static Future<Uint8List> decrypt(List<int> data, String password) async {
    if (data.length < saltLength + nonceLength + 16) {
      throw StateError('Invalid data length');
    }
    final algorithm = AesGcm.with256bits();
    final salt = data.sublist(0, saltLength);
    final nonce = data.sublist(saltLength, saltLength + nonceLength);
    final macBytes = data.sublist(data.length - 16);
    final cipherText = data.sublist(saltLength + nonceLength, data.length - 16);

    final key = await _deriveKey(password, salt);
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final plain = await algorithm.decrypt(box, secretKey: key);
    return Uint8List.fromList(plain);
  }
}
