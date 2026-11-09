import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:file_vault/services/cloud/cloud_auth.dart';
import 'package:file_vault/services/cloud/cloud_client.dart';
import 'package:file_vault/services/cloud/cloud_vaults.dart';
import 'package:file_vault/services/offline/local_vault_store.dart';
import 'package:file_vault/services/offline/vault_repository.dart';

class MemoryTokenStore implements TokenStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// In-memory stand-in for the Supabase auth + REST endpoints the app uses,
/// including the version trigger and unique constraints of the migration.
class FakeSupabase {
  static const url = 'https://fake.supabase.co';
  static const key = 'sb_publishable_test';

  final Map<String, String> users = {}; // email -> password
  final Map<String, String> _refreshTokens = {}; // token -> email
  final Map<String, String> _accessTokens = {}; // token -> email
  final List<Map<String, dynamic>> vaults = [];
  final List<Map<String, dynamic>> files = [];
  bool requireEmailConfirmation = false;

  /// Requests fail as if there were no connection.
  bool offline = false;
  int _seq = 0;
  int requests = 0;

  late final http.Client client = MockClient((req) {
    if (offline) throw http.ClientException('Network is unreachable');
    return _handle(req);
  });

  /// A device with its own connection, unaffected by [offline].
  late final http.Client otherDeviceClient = MockClient(_handle);

  CloudAuth auth({TokenStore? store, bool otherDevice = false}) => CloudAuth(
    baseUrl: url,
    apiKey: key,
    client: otherDevice ? otherDeviceClient : client,
    store: store ?? MemoryTokenStore(),
  );

  CloudVaultRepository repository(CloudAuth auth, {bool otherDevice = false}) =>
      CloudVaultRepository(
        CloudClient(auth, client: otherDevice ? otherDeviceClient : client),
      );

  /// The app's offline-capable repository, keeping its copy in [dir].
  VaultRepository offlineRepository(CloudAuth auth, Directory dir) =>
      VaultRepository(
        remote: repository(auth),
        store: LocalVaultStore(() async => dir),
      );

  /// Invalidates all access tokens, as if they had expired.
  void expireAccessTokens() => _accessTokens.clear();

  String _id() => 'id-${++_seq}';

  Future<http.Response> _handle(http.Request req) async {
    requests++;
    if (req.headers['apikey'] != key) return _json(401, {'msg': 'No API key'});
    final path = req.url.path;
    if (path.startsWith('/auth/v1/')) return _auth(req);
    if (path.startsWith('/rest/v1/')) {
      final email =
          _accessTokens[(req.headers['Authorization'] ?? '').replaceFirst(
            'Bearer ',
            '',
          )];
      if (email == null) return _json(401, {'message': 'JWT expired'});
      return _rest(req, path.substring('/rest/v1/'.length), email);
    }
    return _json(404, {});
  }

  http.Response _session(String email) {
    final access = 'at-${_id()}';
    final refresh = 'rt-${_id()}';
    _accessTokens[access] = email;
    _refreshTokens[refresh] = email;
    return _json(200, {
      'access_token': access,
      'refresh_token': refresh,
      'expires_in': 3600,
      'user': {'email': email},
    });
  }

  http.Response _auth(http.Request req) {
    final body = req.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(req.body) as Map<String, dynamic>;
    final grant = req.url.queryParameters['grant_type'];
    switch (req.url.path) {
      case '/auth/v1/signup':
        final email = body['email'] as String;
        if (users.containsKey(email)) {
          return _json(422, {'msg': 'User already registered'});
        }
        users[email] = body['password'] as String;
        if (requireEmailConfirmation) return _json(200, {'id': _id()});
        return _session(email);
      case '/auth/v1/token' when grant == 'password':
        final email = body['email'] as String;
        if (users[email] != body['password']) {
          return _json(400, {'error_description': 'Invalid login credentials'});
        }
        return _session(email);
      case '/auth/v1/token' when grant == 'refresh_token':
        // Refresh tokens are single-use.
        final email = _refreshTokens.remove(body['refresh_token']);
        if (email == null) {
          return _json(400, {'error_description': 'Invalid Refresh Token'});
        }
        return _session(email);
      case '/auth/v1/logout':
        return http.Response('', 204);
    }
    return _json(404, {});
  }

  List<Map<String, dynamic>> _table(String name) => switch (name) {
    'vaults' => vaults,
    'vault_files' => files,
    _ => throw ArgumentError(name),
  };

  bool _matches(Map<String, dynamic> row, Map<String, String> query) {
    for (final e in query.entries) {
      if (const {'select', 'order'}.contains(e.key)) continue;
      final value = '${row[e.key]}';
      if (e.value.startsWith('eq.')) {
        if (value != e.value.substring(3)) return false;
      } else if (e.value.startsWith('in.(') && e.value.endsWith(')')) {
        final options = e.value.substring(4, e.value.length - 1).split(',');
        if (!options.contains(value)) return false;
      } else {
        throw UnsupportedError(e.value);
      }
    }
    return true;
  }

  Map<String, dynamic> _project(Map<String, dynamic> row, String? select) {
    if (select == null || select == '*') return Map.of(row);
    return {for (final c in select.split(',')) c: row[c]};
  }

  http.Response _rest(http.Request req, String table, String email) {
    final rows = _table(table);
    final query = req.url.queryParameters;
    final select = query['select'];
    // Row-level security: only the caller's rows exist.
    final visible = rows
        .where((r) => r['owner_id'] == email && _matches(r, query))
        .toList();

    switch (req.method) {
      case 'GET':
        if (query['order'] == 'name.asc') {
          visible.sort((a, b) => (a['name'] as String).compareTo(b['name']));
        }
        return _json(200, [for (final r in visible) _project(r, select)]);
      case 'POST':
        final values = jsonDecode(req.body) as Map<String, dynamic>;
        if (values['id'] != null && rows.any((r) => r['id'] == values['id'])) {
          return _conflict(); // Primary key.
        }
        final row = <String, dynamic>{
          ...values,
          'id': values['id'] ?? _id(),
          'owner_id': email,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        if (table == 'vaults') {
          row['auto_backup_enabled'] ??= false;
          if (vaults.any(
            (v) => v['owner_id'] == email && v['name'] == row['name'],
          )) {
            return _conflict();
          }
        } else {
          final vault = vaults.where(
            (v) => v['id'] == row['vault_id'] && v['owner_id'] == email,
          );
          if (vault.isEmpty) return _json(403, {'message': 'RLS'});
          if (_nameTaken(row['vault_id'], row['name'])) return _conflict();
          row['version'] = 1;
          _touch(row);
        }
        rows.add(row);
        return _json(201, [_project(row, select)]);
      case 'PATCH':
        final values = jsonDecode(req.body) as Map<String, dynamic>;
        for (final row in visible) {
          if (table == 'vault_files' &&
              values['name'] != null &&
              values['name'] != row['name'] &&
              _nameTaken(row['vault_id'], values['name'])) {
            return _conflict();
          }
        }
        for (final row in visible) {
          final contentChanged =
              values.containsKey('content') &&
              values['content'] != row['content'];
          row.addAll(values);
          if (table == 'vault_files' && contentChanged) {
            row['version'] = (row['version'] as int) + 1;
            _touch(row);
          }
        }
        return _json(200, [for (final r in visible) _project(r, select)]);
      case 'DELETE':
        rows.removeWhere(visible.contains);
        if (table == 'vaults') {
          files.removeWhere(
            (f) => visible.any((v) => v['id'] == f['vault_id']),
          );
        }
        if (req.headers['Prefer'] == 'return=representation') {
          return _json(200, [for (final r in visible) _project(r, select)]);
        }
        return http.Response('', 204);
    }
    return _json(405, {});
  }

  bool _nameTaken(Object? vaultId, Object? name) =>
      files.any((f) => f['vault_id'] == vaultId && f['name'] == name);

  void _touch(Map<String, dynamic> row) {
    row['updated_at'] = DateTime.now().toUtc().toIso8601String();
    row['size'] = base64Decode(row['content'] as String).length;
  }

  http.Response _conflict() => _json(409, {
    'code': '23505',
    'message': 'duplicate key value violates unique constraint',
  });

  static http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}
