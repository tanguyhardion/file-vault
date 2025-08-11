import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Provides password-based encryption/decryption for .fva files.
///
/// File format (simple container):
/// - 4 bytes magic: 'FVA1'
/// - 16 bytes salt (for PBKDF2-HMAC-SHA256)
/// - 12 bytes nonce (AES-GCM standard nonce size)
/// - N bytes ciphertext
/// - 16 bytes GCM tag (MAC)
class CryptoService {
  static const _magic = [0x46, 0x56, 0x41, 0x31]; // 'FVA1'
  static const int _saltLength = 16;
  static const int _nonceLength = 12; // AES-GCM standard
  static const int _macLength = 16; // AES-GCM tag length
  static const int _derivedKeyLength = 32; // 256-bit key
  static const int _pbkdf2Iterations = 150000;

  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: _derivedKeyLength * 8,
  );

  /// Encrypts a UTF-8 string with the given password and returns a binary
  /// .fva payload including header (magic+salt+nonce) and auth tag.
  static Future<Uint8List> encryptString({
    required String content,
    required String password,
    List<int>? saltOverride,
  }) async {
    final contentBytes = utf8.encode(content);

    // Generate salt and nonce.
    final salt = (saltOverride != null && saltOverride.length == _saltLength)
        ? Uint8List.fromList(saltOverride)
        : _randomBytes(_saltLength);
    final nonce = _aesGcm.newNonce(); // 12 bytes

    // Derive key via PBKDF2-HMAC-SHA256
    final secretKey = await _deriveKey(password: password, salt: salt);

    final secretBox = await _aesGcm.encrypt(
      contentBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Compose container: magic | salt | nonce | ciphertext | mac
    final totalLength =
        4 +
        _saltLength +
        _nonceLength +
        secretBox.cipherText.length +
        _macLength;
    final out = Uint8List(totalLength);
    var offset = 0;

    out.setRange(offset, offset + 4, _magic);
    offset += 4;

    out.setRange(offset, offset + _saltLength, salt);
    offset += _saltLength;

    out.setRange(offset, offset + _nonceLength, nonce);
    offset += _nonceLength;

    out.setRange(
      offset,
      offset + secretBox.cipherText.length,
      secretBox.cipherText,
    );
    offset += secretBox.cipherText.length;

    out.setRange(offset, offset + _macLength, secretBox.mac.bytes);

    return out;
  }

  /// Decrypts an .fva binary payload to a UTF-8 string using the password.
  static Future<String> decryptToString({
    required Uint8List data,
    required String password,
  }) async {
    if (data.length < 4 + _saltLength + _nonceLength + _macLength) {
      throw const FormatException('Invalid FVA file: too small');
    }

    int offset = 0;
    final magic = data.sublist(offset, offset + 4);
    offset += 4;

    for (int i = 0; i < 4; i++) {
      if (magic[i] != _magic[i]) {
        throw const FormatException('Invalid FVA file: bad magic');
      }
    }

    final salt = data.sublist(offset, offset + _saltLength);
    offset += _saltLength;

    final nonce = data.sublist(offset, offset + _nonceLength);
    offset += _nonceLength;

    final cipherTextLen = data.length - offset - _macLength;
    // Allow zero-length ciphertext (valid for AES-GCM with empty plaintext)
    if (cipherTextLen < 0) {
      throw const FormatException('Invalid FVA file: truncated payload');
    }

    final cipherText = data.sublist(offset, offset + cipherTextLen);
    offset += cipherTextLen;

    final macBytes = data.sublist(offset, offset + _macLength);

    final secretKey = await _deriveKey(password: password, salt: salt);

    try {
      final clearBytes = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );
      return utf8.decode(clearBytes);
    } on SecretBoxAuthenticationError {
      // Wrong password or corrupted data
      throw const FormatException('Decryption failed. Wrong password?');
    }
  }

  // Generate a random salt for password hashing
  static Uint8List randomSalt([int length = _saltLength]) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }

  // Hash a password with PBKDF2-HMAC-SHA256
  static Future<Uint8List> hashPassword({
    required String password,
    required Uint8List salt,
  }) async {
    final pwBytes = utf8.encode(password);
    final keyBytes = await _pbkdf2.deriveKey(
      secretKey: SecretKey(pwBytes),
      nonce: salt,
    );
    final raw = await keyBytes.extractBytes();
    return Uint8List.fromList(raw);
  }

  static Future<SecretKey> _deriveKey({
    required String password,
    required List<int> salt,
  }) async {
    final pwBytes = utf8.encode(password);
    final keyBytes = await _pbkdf2.deriveKey(
      secretKey: SecretKey(pwBytes),
      nonce: salt,
    );
    return keyBytes;
  }

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }
}
