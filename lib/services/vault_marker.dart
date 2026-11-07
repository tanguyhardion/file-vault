import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'crypto_service.dart';

/// Parsed contents of a vault's `.vault_marker` file.
///
/// The marker only holds the PBKDF2 salt and hash of the vault password, so it
/// is safe to store alongside the encrypted files (e.g. in OneDrive).
class VaultMarker {
  static const fileName = '.vault_marker';

  final List<int> salt;
  final List<int> passwordHash;

  const VaultMarker({required this.salt, required this.passwordHash});

  /// Parses marker contents. Returns null if the salt or hash is missing.
  static VaultMarker? tryParse(String contents) {
    final lines = contents.split('\n');
    String valueOf(String key) => lines
        .firstWhere((l) => l.startsWith('$key: '), orElse: () => '')
        .replaceFirst('$key: ', '')
        .trim();

    final salt = valueOf('salt');
    final hash = valueOf('password_hash');
    if (salt.isEmpty || hash.isEmpty) return null;
    try {
      return VaultMarker(
        salt: base64Decode(salt),
        passwordHash: base64Decode(hash),
      );
    } on FormatException {
      return null;
    }
  }

  Future<bool> verifyPassword(String password) async {
    final inputHash = await CryptoService.hashPassword(
      password: password,
      salt: Uint8List.fromList(salt),
    );
    return const ListEquality<int>().equals(passwordHash, inputHash);
  }
}
