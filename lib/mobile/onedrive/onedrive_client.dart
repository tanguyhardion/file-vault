import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../services/vault_service.dart';
import '../storage/vault_storage.dart';
import 'onedrive_auth.dart';
import 'onedrive_config.dart';

/// A file or folder in the user's OneDrive.
class DriveItem {
  final String id;
  final String name;
  final bool isFolder;
  final int size;

  /// Changes whenever the item changes; used for optimistic concurrency.
  final String eTag;
  final DateTime? lastModified;

  const DriveItem({
    required this.id,
    required this.name,
    required this.isFolder,
    required this.size,
    required this.eTag,
    this.lastModified,
  });

  factory DriveItem.fromJson(Map<String, dynamic> json) => DriveItem(
    id: json['id'] as String,
    name: json['name'] as String,
    isFolder: json['folder'] != null,
    size: (json['size'] as num?)?.toInt() ?? 0,
    eTag: json['eTag'] as String? ?? '',
    lastModified: DateTime.tryParse(json['lastModifiedDateTime'] ?? ''),
  );
}

class OneDriveException implements Exception {
  final int statusCode;
  final String message;

  const OneDriveException(this.statusCode, this.message);

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'OneDrive error $statusCode: $message';
}

/// Minimal Microsoft Graph client for the signed-in user's OneDrive.
///
/// Callers only ever pass already-encrypted bytes to the upload methods.
class OneDriveClient {
  static const _itemFields =
      'id,name,size,eTag,lastModifiedDateTime,folder,file';

  final OneDriveAuth _auth;
  final http.Client _http;

  OneDriveClient(this._auth, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  /// Use `'root'` for the top of the drive.
  Future<DriveItem> getItem(String itemId) async {
    final res = await _send(
      'GET',
      _itemPath(itemId),
      query: {r'$select': _itemFields},
    );
    return DriveItem.fromJson(_decode(res));
  }

  Future<List<DriveItem>> listChildren(String folderId) async {
    final items = <DriveItem>[];
    Uri? next = _uri(
      '${_itemPath(folderId)}/children',
      query: {r'$select': _itemFields, r'$top': '999'},
    );
    while (next != null) {
      final res = await _sendUri('GET', next);
      final json = _decode(res);
      for (final raw in json['value'] as List) {
        items.add(DriveItem.fromJson(raw as Map<String, dynamic>));
      }
      final link = json['@odata.nextLink'] as String?;
      next = link == null ? null : Uri.parse(link);
    }
    return items;
  }

  /// Downloads file content. Fetch the item's metadata (eTag) *before* calling
  /// this so a concurrent change surfaces as a conflict on the next upload
  /// rather than being silently overwritten.
  Future<Uint8List> download(String itemId) async {
    // Graph answers with a 302 to a pre-authenticated URL. Follow it manually
    // so the bearer token is not forwarded to another host.
    final res = await _send(
      'GET',
      '${_itemPath(itemId)}/content',
      followRedirects: false,
    );
    if (res.statusCode == 302 || res.statusCode == 301) {
      final location = res.headers['location'];
      if (location == null) {
        throw const OneDriveException(502, 'Missing download location');
      }
      final contentRes = await _http.get(Uri.parse(location));
      _check(contentRes);
      return contentRes.bodyBytes;
    }
    return res.bodyBytes;
  }

  /// Replaces a file's content. If [ifMatchETag] is given and the file changed
  /// since then, throws [FileChangedExternallyException].
  Future<DriveItem> replaceContent(
    String itemId,
    Uint8List bytes, {
    String? ifMatchETag,
  }) async {
    final res = await _send(
      'PUT',
      '${_itemPath(itemId)}/content',
      body: bytes,
      headers: {
        'Content-Type': 'application/octet-stream',
        'If-Match': ?ifMatchETag,
      },
      checkStatus: false,
    );
    if (res.statusCode == 412) throw FileChangedExternallyException();
    _check(res);
    return DriveItem.fromJson(_decode(res));
  }

  /// Creates a new file in [parentId]; fails if the name is taken.
  Future<DriveItem> createFile(
    String parentId,
    String name,
    Uint8List bytes,
  ) async {
    final res = await _send(
      'PUT',
      '${_itemPath(parentId)}:/${Uri.encodeComponent(name)}:/content',
      query: {'@microsoft.graph.conflictBehavior': 'fail'},
      body: bytes,
      headers: {'Content-Type': 'application/octet-stream'},
      checkStatus: false,
    );
    if (res.statusCode == 409) throw NameConflictException(name);
    _check(res);
    return DriveItem.fromJson(_decode(res));
  }

  Future<DriveItem> rename(String itemId, String newName) async {
    final res = await _send(
      'PATCH',
      _itemPath(itemId),
      body: utf8.encode(jsonEncode({'name': newName})),
      headers: {'Content-Type': 'application/json'},
      checkStatus: false,
    );
    if (res.statusCode == 409) throw NameConflictException(newName);
    _check(res);
    return DriveItem.fromJson(_decode(res));
  }

  /// Moves the item to the OneDrive recycle bin.
  Future<void> delete(String itemId) async {
    await _send('DELETE', _itemPath(itemId));
  }

  String _itemPath(String itemId) => '/me/drive/items/$itemId';

  Uri _uri(String path, {Map<String, String>? query}) => Uri.parse(
    '${OneDriveConfig.graphBaseUrl}$path',
  ).replace(queryParameters: query);

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    List<int>? body,
    bool followRedirects = true,
    bool checkStatus = true,
  }) => _sendUri(
    method,
    _uri(path, query: query),
    headers: headers,
    body: body,
    followRedirects: followRedirects,
    checkStatus: checkStatus,
  );

  Future<http.Response> _sendUri(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    List<int>? body,
    bool followRedirects = true,
    bool checkStatus = true,
  }) async {
    Future<http.Response> attempt({required bool forceRefresh}) async {
      final token = await _auth.getAccessToken(forceRefresh: forceRefresh);
      final req = http.Request(method, uri)
        ..followRedirects = followRedirects
        ..headers['Authorization'] = 'Bearer $token'
        ..headers.addAll(headers ?? const {});
      if (body != null) req.bodyBytes = body;
      return http.Response.fromStream(await _http.send(req));
    }

    var res = await attempt(forceRefresh: false);
    if (res.statusCode == 401) {
      res = await attempt(forceRefresh: true);
    }
    if (checkStatus) _check(res);
    return res;
  }

  void _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 400) return;
    var message = res.reasonPhrase ?? 'Request failed';
    try {
      final error = (jsonDecode(res.body) as Map)['error'] as Map?;
      message = error?['message'] as String? ?? message;
    } catch (_) {
      // Non-JSON error body; keep the reason phrase.
    }
    throw OneDriveException(res.statusCode, message);
  }

  Map<String, dynamic> _decode(http.Response res) =>
      jsonDecode(res.body) as Map<String, dynamic>;
}
