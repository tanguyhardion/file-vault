import 'dart:collection';

class _CacheEntry {
  final String content;
  final String version;

  _CacheEntry(this.content, this.version);
}

/// LRU cache for decrypted file contents keyed by file ID and version.
class ContentCache {
  static final ContentCache instance = ContentCache._(maxEntries: 10);

  final int maxEntries;
  final LinkedHashMap<String, _CacheEntry> _map = LinkedHashMap();

  ContentCache._({required this.maxEntries});

  void clear() => _map.clear();

  String? getIfFresh(String id, String version) {
    final entry = _map.remove(id);
    if (entry == null) return null;
    if (entry.version == version) {
      // reinsert to update LRU order
      _map[id] = entry;
      return entry.content;
    }
    return null;
  }

  void put(String id, String content, String version) {
    _map.remove(id);
    _map[id] = _CacheEntry(content, version);
    if (_map.length > maxEntries) {
      // remove oldest
      _map.remove(_map.keys.first);
    }
  }
}
