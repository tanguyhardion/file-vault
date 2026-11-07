// Uses the Android implementation directly (not the local_auth app package)
// so no screen lock plugin is compiled into the Windows build.
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

/// The user dismissed the screen lock prompt.
class DeviceAuthCancelledException implements Exception {}

class DeviceAuthException implements Exception {
  final String message;
  const DeviceAuthException(this.message);

  @override
  String toString() => message;
}

/// Requires the phone's screen lock (fingerprint, face, PIN, pattern or
/// password) as a gate in front of every vault password attempt.
class DeviceAuth {
  DeviceAuth._();

  static LocalAuthPlatform get _auth => LocalAuthPlatform.instance;

  static const _noScreenLock = DeviceAuthException(
    'Set up a screen lock (PIN, pattern, password or biometrics) in Android '
    'settings to open vaults on this phone.',
  );

  /// Completes normally only if the user passed the screen lock.
  static Future<void> require({required String reason}) async {
    if (!await _auth.isDeviceSupported()) throw _noScreenLock;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const [AndroidAuthMessages()],
        options: const AuthenticationOptions(
          // Allow PIN/pattern/password, not only biometrics.
          biometricOnly: false,
          // Errors are reported as LocalAuthException and handled below.
          useErrorDialogs: false,
        ),
      );
      if (!ok) throw const DeviceAuthException('Screen lock not verified.');
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
          throw DeviceAuthCancelledException();
        case LocalAuthExceptionCode.noCredentialsSet:
          throw _noScreenLock;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          throw const DeviceAuthException(
            'Too many screen lock attempts. Try again later.',
          );
        default:
          throw DeviceAuthException(
            'Screen lock verification failed: ${e.description ?? e.code.name}',
          );
      }
    }
  }
}
