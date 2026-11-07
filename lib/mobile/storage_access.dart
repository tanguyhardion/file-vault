import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// "All files access" on Android, needed to read and write vault folders in
/// shared storage (implemented in MainActivity.kt).
class StorageAccess {
  StorageAccess._();

  static const _channel = MethodChannel('file_vault/storage');

  static Future<bool> get granted async =>
      await _channel.invokeMethod<bool>('hasAccess') ?? false;

  /// Root of the phone's shared storage, e.g. `/storage/emulated/0`.
  static Future<String> get storageRoot async =>
      await _channel.invokeMethod<String>('storageRoot') ??
      '/storage/emulated/0';

  /// Ensures access, sending the user to the system settings page if needed.
  /// Returns whether access was granted.
  static Future<bool> ensure() async {
    if (await granted) return true;
    final returned = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!returned.isCompleted) returned.complete();
      },
    );
    try {
      await _channel.invokeMethod<void>('requestAccess');
      await returned.future;
    } finally {
      listener.dispose();
    }
    return granted;
  }
}
