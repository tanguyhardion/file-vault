import 'package:flutter/material.dart';

import '../models/vault_models.dart';
import '../services/vault_service.dart';
import '../services/crypto_worker.dart';
import '../services/content_cache.dart';
import 'vault_controller.dart';

class SearchController extends ChangeNotifier {
  final VaultController _vaultController;
  final TextEditingController _searchController = TextEditingController();
  List<VaultFileEntry> _filteredFiles = [];
  bool _isSearching = false;

  SearchController(this._vaultController) {
    _searchController.addListener(_onSearchChanged);
  }

  TextEditingController get searchController => _searchController;
  List<VaultFileEntry> get filteredFiles => _filteredFiles;
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
      final fileName = file.fileName.toLowerCase();
      return fileName.contains(query);
    }).toList();

    _filteredFiles = nameMatches;
    notifyListeners();

    // Search by content (async, will update results when complete)
    _searchByContent(query, nameMatches);
  }

  Future<void> _searchByContent(String query, List<VaultFileEntry> nameMatches) async {
    final password = _vaultController.vaultPassword;
    if (password == null) {
      _isSearching = false;
      notifyListeners();
      return;
    }

    final contentMatches = <VaultFileEntry>[];
    
    // Add files that match by name first
    contentMatches.addAll(nameMatches);
    
    // Search through file contents
    for (final file in _vaultController.files) {
      // Skip if already matched by name
      if (nameMatches.any((f) => f.fullPath == file.fullPath)) {
        continue;
      }

      try {
        // Try to get from cache first
        final fp = await VaultService.getFingerprint(file.fullPath);
        String content = ContentCache.instance.getIfFresh(file.fullPath, fp) ?? '';
        
        // If not in cache, decrypt the file
        if (content.isEmpty) {
          final bytes = await VaultService.readVaultFileBytes(file.fullPath);
          if (bytes.isNotEmpty) {
            content = await CryptoWorker.decryptToString(
              data: bytes,
              password: password,
            );
            // Cache the decrypted content
            ContentCache.instance.put(file.fullPath, content, fp);
          }
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
