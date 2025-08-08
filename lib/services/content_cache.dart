import 'dart:collection';

import 'vault_service.dart';

class _CacheEntry {
  final String content;
  final FileFingerprint fp;

  _CacheEntry(this.content, this.fp);
}

/// LRU cache for decrypted file contents keyed by full path.
class ContentCache {
  static final ContentCache instance = ContentCache._(maxEntries: 10);

  final int maxEntries;
  final LinkedHashMap<String, _CacheEntry> _map = LinkedHashMap();

  ContentCache._({required this.maxEntries});

  void clear() => _map.clear();

  String? getIfFresh(String path, FileFingerprint fp) {
    final entry = _map.remove(path);
    if (entry == null) return null;
    if (entry.fp == fp) {
      // reinsert to update LRU order
      _map[path] = entry;
      return entry.content;
    }
    return null;
  }

  void put(String path, String content, FileFingerprint fp) {
    _map.remove(path);
    _map[path] = _CacheEntry(content, fp);
    if (_map.length > maxEntries) {
      // remove oldest
      _map.remove(_map.keys.first);
    }
  }
}
