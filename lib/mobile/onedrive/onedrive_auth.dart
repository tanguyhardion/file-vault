import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'onedrive_config.dart';

/// Handles Microsoft sign-in (OAuth 2.0 auth code + PKCE) and token refresh.
///
/// Only the refresh token is persisted, in Android Keystore-backed storage.
/// Access tokens live in memory. Neither grants access to vault contents:
/// they only allow reading/writing the encrypted files in OneDrive.
class OneDriveAuth extends ChangeNotifier {
  static const _refreshTokenKey = 'onedrive_refresh_token';

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _serviceConfiguration = AuthorizationServiceConfiguration(
    authorizationEndpoint: OneDriveConfig.authorizationEndpoint,
    tokenEndpoint: OneDriveConfig.tokenEndpoint,
  );

  String? _accessToken;
  DateTime? _accessTokenExpiry;
  String? _refreshToken;
  bool _initialized = false;

  bool get initialized => _initialized;
  bool get isSignedIn => _refreshToken != null;

  /// Loads a previously stored session, if any.
  Future<void> init() async {
    _refreshToken = await _storage.read(key: _refreshTokenKey);
    _initialized = true;
    notifyListeners();
  }

  /// Opens the Microsoft sign-in page. Returns false if the user cancelled.
  Future<bool> signIn() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          OneDriveConfig.clientId,
          OneDriveConfig.redirectUrl,
          serviceConfiguration: _serviceConfiguration,
          scopes: OneDriveConfig.scopes,
          promptValues: const ['select_account'],
        ),
      );
      await _storeTokens(result);
      return true;
    } on FlutterAppAuthUserCancelledException {
      return false;
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _accessTokenExpiry = null;
    _refreshToken = null;
    await _storage.delete(key: _refreshTokenKey);
    notifyListeners();
  }

  /// Returns a valid access token, refreshing it when close to expiry.
  /// Pass [forceRefresh] after the API rejected the current token.
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    final expiry = _accessTokenExpiry;
    if (!forceRefresh &&
        _accessToken != null &&
        expiry != null &&
        DateTime.now().isBefore(expiry.subtract(const Duration(minutes: 2)))) {
      return _accessToken!;
    }

    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      throw const OneDriveAuthException('Not signed in to OneDrive');
    }

    try {
      final result = await _appAuth.token(
        TokenRequest(
          OneDriveConfig.clientId,
          OneDriveConfig.redirectUrl,
          serviceConfiguration: _serviceConfiguration,
          scopes: OneDriveConfig.scopes,
          refreshToken: refreshToken,
        ),
      );
      await _storeTokens(result);
    } on FlutterAppAuthPlatformException catch (e) {
      // invalid_grant: refresh token expired or revoked; a new sign-in is needed.
      if (e.platformErrorDetails.error == 'invalid_grant') {
        await signOut();
        throw const OneDriveAuthException(
          'OneDrive session expired. Please sign in again.',
        );
      }
      rethrow;
    }
    return _accessToken!;
  }

  Future<void> _storeTokens(TokenResponse result) async {
    _accessToken = result.accessToken;
    _accessTokenExpiry = result.accessTokenExpirationDateTime;
    // Microsoft rotates refresh tokens; keep the newest one.
    final newRefresh = result.refreshToken;
    if (newRefresh != null && newRefresh != _refreshToken) {
      _refreshToken = newRefresh;
      await _storage.write(key: _refreshTokenKey, value: newRefresh);
    }
    notifyListeners();
  }
}

class OneDriveAuthException implements Exception {
  final String message;
  const OneDriveAuthException(this.message);

  @override
  String toString() => message;
}
