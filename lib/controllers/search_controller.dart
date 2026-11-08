import 'package:material_ui/material_ui.dart';

import '../services/content_cache.dart';
import '../services/storage/vault_storage.dart';
import 'vault_controller.dart';

class SearchController extends ChangeNotifier {
  final VaultController _vaultController;
  final TextEditingController _searchController = TextEditingController();
  List<VaultItem> _filteredFiles = [];
  bool _isSearching = false;

  SearchController(this._vaultController) {
    _searchController.addListener(_onSearchChanged);
  }

  TextEditingController get searchController => _searchController;
  List<VaultItem> get filteredFiles => _filteredFiles;
  bool get isSearching => _isSearching;
  bool get hasSearchQuery => _searchController.text.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void clearSearch() {
    _searchController.clear();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      _filteredFiles = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    // Search by filename first (immediate)
    final nameMatches = _vaultController.files.where((file) {
      final fileName = file.name.toLowerCase();
      return fileName.contains(query);
    }).toList();

    _filteredFiles = nameMatches;
    notifyListeners();

    // Search by content (async, will update results when complete)
    _searchByContent(query, nameMatches);
  }

  Future<void> _searchByContent(
    String query,
    List<VaultItem> nameMatches,
  ) async {
    final session = _vaultController.session;
    if (session == null || session.isLocked) {
      _isSearching = false;
      notifyListeners();
      return;
    }

    final contentMatches = <VaultItem>[];

    // Add files that match by name first
    contentMatches.addAll(nameMatches);

    // Search through file contents
    for (final file in _vaultController.files) {
      // Skip if already matched by name
      if (nameMatches.any((f) => f.id == file.id)) {
        continue;
      }

      try {
        // Try to get from cache first
        var content = ContentCache.instance.getIfFresh(file.id, file.version);

        // If not in cache, download and decrypt the file
        if (content == null) {
          content = await session.decrypt(file);
          ContentCache.instance.put(file.id, content, file.version);
        }

        // Check if content contains the search query
        if (content.toLowerCase().contains(query)) {
          contentMatches.add(file);
        }
      } catch (e) {
        // Skip files that can't be decrypted or read
        continue;
      }
    }

    // Update the filtered list with all matches (only if search query hasn't changed)
    if (_searchController.text.toLowerCase().trim() == query) {
      _filteredFiles = contentMatches;
      _isSearching = false;
      notifyListeners();
    }
  }

  void triggerSearch() {
    if (_searchController.text.isNotEmpty) {
      _onSearchChanged();
    }
  }
}
