import 'package:flutter/foundation.dart';

import 'crypto_service.dart';

/// Runs crypto operations in a background isolate to keep the UI responsive.
///
/// Wall-clock time of PBKDF2/AES stays the same, but moving work off the main
/// isolate eliminates jank and makes opening files feel faster.
class CryptoWorker {
  /// Encrypt a UTF-8 string to an .fva payload in a background isolate.
  static Future<Uint8List> encryptString({
    required String content,
    required String password,
  }) async {
    final res = await compute<_EncryptArgs, Uint8List>(
      _encryptEntryPoint,
      _EncryptArgs(content: content, password: password),
    );
    return res;
  }

  /// Decrypt an .fva binary payload to a UTF-8 string in a background isolate.
  static Future<String> decryptToString({
    required Uint8List data,
    required String password,
  }) async {
    final res = await compute<_DecryptArgs, String>(
      _decryptEntryPoint,
      _DecryptArgs(data: data, password: password),
    );
    return res;
  }
}

// Arguments for compute must be simple values; keep them in small containers.
class _EncryptArgs {
  final String content;
  final String password;

  const _EncryptArgs({required this.content, required this.password});
}

class _DecryptArgs {
  final Uint8List data;
  final String password;

  const _DecryptArgs({required this.data, required this.password});
}

// Top-level entry points for compute()
Future<Uint8List> _encryptEntryPoint(_EncryptArgs args) async {
  return CryptoService.encryptString(
    content: args.content,
    password: args.password,
  );
}

Future<String> _decryptEntryPoint(_DecryptArgs args) async {
  return CryptoService.decryptToString(
    data: args.data,
    password: args.password,
  );
}
