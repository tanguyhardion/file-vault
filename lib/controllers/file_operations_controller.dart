import 'package:material_ui/material_ui.dart';

import '../services/content_cache.dart';
import '../services/storage/vault_storage.dart';
import '../services/vault_session.dart';
import 'vault_controller.dart';

class FileOperationsController extends ChangeNotifier {
  final VaultController _vaultController;
  // Holds the version it was read at; saving fails if another device changed
  // the file since.
  OpenedVaultFile? _openedContent;
  bool _dirty = false;
  bool _loading = false;

  FileOperationsController(this._vaultController);

  OpenedVaultFile? get openedContent => _openedContent;
  bool get dirty => _dirty;
  bool get loading => _loading;

  void setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }

  void setDirty(bool dirty) {
    _dirty = dirty;
    notifyListeners();
  }

  VaultSession _requireSession() {
    final session = _vaultController.session;
    if (session == null || session.isLocked) {
      throw Exception('No vault is open');
    }
    return session;
  }

  Future<T> _withLoading<T>(Future<T> Function() action) async {
    setLoading(true);
    try {
      return await action();
    } finally {
      setLoading(false);
    }
  }

  Future<void> openFile(VaultItem file) => _withLoading(() async {
    final opened = await _requireSession().openFile(file);
    _openedContent = opened;
    _dirty = false;
    ContentCache.instance.put(
      opened.item.id,
      opened.content,
      opened.item.version,
    );
  });

  Future<VaultItem> createNewFile(String name) => _withLoading(() async {
    final opened = await _requireSession().createFile(name);
    _openedContent = opened;
    _dirty = false;
    return opened.item;
  });

  /// Throws [FileChangedExternallyException] if the file changed on another
  /// device since it was opened, unless [overwrite] is set.
  Future<void> saveCurrentFile(String content, {bool overwrite = false}) async {
    final current = _openedContent;
    if (current == null) return;
    await _withLoading(() async {
      final saved = await _requireSession().save(
        current,
        content,
        overwrite: overwrite,
      );
      _openedContent = saved;
      _dirty = false;
      ContentCache.instance.put(saved.item.id, content, saved.item.version);
    });
  }

  Future<VaultItem> renameFile(VaultItem file, String newName) =>
      _withLoading(() async {
        final updated = await _requireSession().renameFile(file, newName);
        final current = _openedContent;
        if (current?.item.id == file.id) {
          _openedContent = OpenedVaultFile(
            item: updated,
            content: current!.content,
          );
        }
        return updated;
      });

  Future<void> deleteFile(VaultItem file) => _withLoading(() async {
    await _requireSession().deleteFile(file);
    if (_openedContent?.item.id == file.id) {
      _openedContent = null;
      _dirty = false;
    }
  });

  void closeFile() {
    _openedContent = null;
    _dirty = false;
    notifyListeners();
  }
}
