import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_auth.dart';

class CloudException implements Exception {
  final int statusCode;

  /// Postgres error code, e.g. `23505` for a unique violation.
  final String? code;
  final String message;

  const CloudException(this.statusCode, this.message, {this.code});

  bool get isUniqueViolation => code == '23505' || statusCode == 409;

  @override
  String toString() => message;
}

/// Minimal client for the Supabase REST (PostgREST) API, signed in as the
/// current [CloudAuth] user.
class CloudClient {
  final CloudAuth auth;
  final http.Client _http;

  CloudClient(this.auth, {http.Client? client})
    : _http = client ?? http.Client();

  /// Rows of [table] matching [query] (PostgREST filters, `select`, `order`).
  Future<List<Map<String, dynamic>>> select(
    String table,
    Map<String, String> query,
  ) async {
    final res = await _send('GET', table, query);
    return _rows(res);
  }

  /// Inserts [row]; returns the inserted row.
  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> row, {
    String? select,
  }) async {
    final res = await _send(
      'POST',
      table,
      {'select': ?select},
      body: row,
      prefer: 'return=representation',
    );
    return _rows(res).single;
  }

  /// Updates rows matching [query]; returns the updated rows (empty if none
  /// matched).
  Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, String> query,
    Map<String, dynamic> values,
  ) async {
    final res = await _send(
      'PATCH',
      table,
      query,
      body: values,
      prefer: 'return=representation',
    );
    return _rows(res);
  }

  Future<void> delete(String table, Map<String, String> query) async {
    await _send('DELETE', table, query);
  }

  Future<http.Response> _send(
    String method,
    String table,
    Map<String, String> query, {
    Object? body,
    String? prefer,
  }) async {
    final uri = Uri.parse(
      '${auth.baseUrl}/rest/v1/$table',
    ).replace(queryParameters: query.isEmpty ? null : query);

    Future<http.Response> attempt(String token) async {
      final req = http.Request(method, uri)
        ..headers.addAll({
          'apikey': auth.apiKey,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Prefer': ?prefer,
        });
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      return http.Response.fromStream(await _http.send(req));
    }

    var res = await attempt(await auth.accessToken());
    if (res.statusCode == 401) {
      res = await attempt(await auth.accessToken(forceRefresh: true));
    }
    if (res.statusCode >= 400) throw _error(res);
    return res;
  }

  static List<Map<String, dynamic>> _rows(http.Response res) {
    if (res.body.isEmpty) return const [];
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  static CloudException _error(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return CloudException(
        res.statusCode,
        (body['message'] as String?) ?? 'Request failed (${res.statusCode}).',
        code: body['code'] as String?,
      );
    } catch (_) {
      return CloudException(
        res.statusCode,
        'Request failed (${res.statusCode}).',
      );
    }
  }
}
