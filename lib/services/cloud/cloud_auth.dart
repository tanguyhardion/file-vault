import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Persists the session's refresh token.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Keystore (Android) / DPAPI (Windows) backed storage.
class SecureTokenStore implements TokenStore {
  static const _storage = FlutterSecureStorage();

  const SecureTokenStore();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class CloudAuthException implements Exception {
  final String message;
  const CloudAuthException(this.message);

  @override
  String toString() => message;
}

/// The account is signed out (or its session expired) and must sign in again.
class NotSignedInException implements Exception {
  @override
  String toString() => 'Signed out. Please sign in again.';
}

/// Email + password sign-in against Supabase Auth.
///
/// The account only grants access to the encrypted rows; it is unrelated to
/// vault passwords, which never leave the device. Only the refresh token is
/// persisted; access tokens live in memory.
class CloudAuth extends ChangeNotifier {
  static const _refreshTokenKey = 'cloud_refresh_token';
  static const _emailKey = 'cloud_email';

  final String baseUrl;
  final String apiKey;
  final http.Client _http;
  final TokenStore _store;

  String? _accessToken;
  DateTime? _accessTokenExpiry;
  String? _refreshToken;
  String? _email;
  bool _initialized = false;
  Future<String>? _refreshing;

  CloudAuth({
    required this.baseUrl,
    required this.apiKey,
    http.Client? client,
    this._store = const SecureTokenStore(),
  }) : _http = client ?? http.Client();

  bool get initialized => _initialized;
  bool get isSignedIn => _refreshToken != null;
  String? get email => _email;

  Future<void> init() async {
    _refreshToken = await _store.read(_refreshTokenKey);
    _email = await _store.read(_emailKey);
    _initialized = true;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final res = await _post('/auth/v1/token?grant_type=password', {
      'email': email.trim(),
      'password': password,
    });
    await _storeSession(_decode(res));
  }

  /// Creates an account. Returns false if the project requires the email to
  /// be confirmed before signing in.
  Future<bool> signUp(String email, String password) async {
    final res = await _post('/auth/v1/signup', {
      'email': email.trim(),
      'password': password,
    });
    final body = _decode(res);
    if (body['access_token'] == null) return false;
    await _storeSession(body);
    return true;
  }

  Future<void> signOut() async {
    final token = _accessToken;
    _clearMemory();
    await _store.delete(_refreshTokenKey);
    notifyListeners();
    if (token != null) {
      try {
        await _http.post(
          Uri.parse('$baseUrl/auth/v1/logout'),
          headers: {'apikey': apiKey, 'Authorization': 'Bearer $token'},
        );
      } catch (_) {
        // Local sign-out is what matters.
      }
    }
  }

  /// A valid access token, refreshed if needed.
  Future<String> accessToken({bool forceRefresh = false}) async {
    final token = _accessToken;
    final expiry = _accessTokenExpiry;
    if (!forceRefresh &&
        token != null &&
        expiry != null &&
        DateTime.now().isBefore(expiry.subtract(const Duration(minutes: 1)))) {
      return token;
    }
    // Refresh tokens are single-use: share one refresh between callers.
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String> _refresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) throw NotSignedInException();
    final res = await _post('/auth/v1/token?grant_type=refresh_token', {
      'refresh_token': refreshToken,
    }, throwOnError: false);
    if (res.statusCode == 400 || res.statusCode == 401) {
      // Revoked or expired: the user has to sign in again.
      _clearMemory();
      await _store.delete(_refreshTokenKey);
      notifyListeners();
      throw NotSignedInException();
    }
    final body = _decode(res);
    await _storeSession(body);
    return _accessToken!;
  }

  Future<void> _storeSession(Map<String, dynamic> body) async {
    final access = body['access_token'] as String?;
    final refresh = body['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw const CloudAuthException('Unexpected response from the server.');
    }
    final wasSignedIn = isSignedIn;
    _accessToken = access;
    _refreshToken = refresh;
    _accessTokenExpiry = DateTime.now().add(
      Duration(seconds: (body['expires_in'] as num?)?.toInt() ?? 3600),
    );
    final email = (body['user'] as Map<String, dynamic>?)?['email'] as String?;
    if (email != null) {
      _email = email;
      await _store.write(_emailKey, email);
    }
    await _store.write(_refreshTokenKey, refresh);
    if (!wasSignedIn) notifyListeners();
  }

  void _clearMemory() {
    _accessToken = null;
    _accessTokenExpiry = null;
    _refreshToken = null;
  }

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    bool throwOnError = true,
  }) async {
    final http.Response res;
    try {
      res = await _http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'apikey': apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } on Exception catch (e) {
      throw CloudAuthException('Could not reach the server: $e');
    }
    if (throwOnError && res.statusCode >= 400) {
      throw CloudAuthException(_errorMessage(res));
    }
    return res;
  }

  static Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode >= 400) throw CloudAuthException(_errorMessage(res));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static String _errorMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final msg = body['msg'] ?? body['error_description'] ?? body['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    } catch (_) {}
    return 'Request failed (${res.statusCode}).';
  }
}
