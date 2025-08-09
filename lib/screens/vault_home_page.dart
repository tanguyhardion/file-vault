import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// path is used in widgets, not directly here

import '../models/vault_models.dart';
import '../services/crypto_service.dart';
import '../services/crypto_worker.dart';
import '../services/content_cache.dart';
import '../services/vault_service.dart';
import '../widgets/dialogs.dart';
import '../shortcuts/save_intent.dart';
import '../services/recent_vaults_service.dart';
import '../widgets/vault_header.dart';
import '../widgets/file_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/content_editor.dart';

class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key});

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  String? _vaultDir;
  String? _vaultPassword;
  List<VaultFileEntry> _files = [];
  DecryptedFileContent? _openedContent;
  bool _loading = false;
  final TextEditingController _editorController = TextEditingController();
  bool _dirty = false;
  int? _hoveredIndex;
  List<String> _recentVaults = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
            const SaveIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (intent) {
              _handleSaveShortcut();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('File Vault'),
              actions: [
                // Create new vault first
                IconButton(
                  tooltip: 'Create new vault',
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: _onCreateVault,
                ),
                Container(
                  width: 1,
                  height: kToolbarHeight - 32,
                  color: Divider.createBorderSide(context).color,
                  margin: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 6,
                  ),
                ),
                // Group: Open vault, Open recent, Close vault
                IconButton(
                  tooltip: 'Open vault',
                  icon: const Icon(Icons.folder_open),
                  onPressed: _onOpenVault,
                ),
                IconButton(
                  tooltip: 'Open recent vaults',
                  icon: const Icon(Icons.history),
                  onPressed: _onShowRecentVaults,
                ),
                if (_vaultDir != null)
                  IconButton(
                    tooltip: 'Close vault',
                    icon: const Icon(Icons.close),
                    onPressed: _onCloseVault,
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: Row(
              children: [
                // Left pane: file list
                SizedBox(
                  width: 260,
                  child: Column(
                    children: [
                      VaultHeader(vaultDir: _vaultDir),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          8,
                          8,
                          8,
                          8,
                        ), // margin at top
                        child: SizedBox(
                          height: 48, // slightly taller
                          child: FilledButton.icon(
                            onPressed:
                                (_vaultDir != null && _vaultPassword != null)
                                ? _onCreateNewFile
                                : null,
                            icon: const Icon(Icons.note_add),
                            label: const Text('New secret file'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _vaultDir == null
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'Open a vault folder to see .fva files',
                                  ),
                                ),
                              )
                            : FileList(
                                files: _files,
                                openedContent: _openedContent,
                                hoveredIndex: _hoveredIndex,
                                onHoverChanged: (i) =>
                                    setState(() => _hoveredIndex = i),
                                onOpenFile: _onOpenFile,
                                onRename: _onRenameFile,
                                onDelete: _onDeleteFile,
                              ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                // Main view
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _openedContent == null
                      ? EmptyState(
                          recentVaults: _recentVaults,
                          onOpenRecent: _onOpenRecent,
                        )
                      : ContentEditor(
                          content: _openedContent!,
                          controller: _editorController,
                          dirty: _dirty,
                          loading: _loading,
                          onSave: _onSaveCurrentFile,
                          onChanged: (v) {
                            if (!_dirty) {
                              setState(() => _dirty = true);
                            }
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onOpenVault() async {
    try {
      final dir = await getDirectoryPath();
      if (!mounted || dir == null) return;
      await _openVaultAt(dir);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open vault: $e')));
      }
    }
  }

  Future<void> _onOpenRecent(String dir) async {
    await _openVaultAt(dir);
  }

  Future<void> _openVaultAt(String dir) async {
    // Prompt for password in a local function to avoid context across async gap
    String? pw;
    if (mounted) {
      pw = await promptForPassword(context, title: 'Vault password');
    }
    if (!mounted || pw == null || pw.isEmpty) return;

    if (mounted) {
      setState(() {
        _vaultDir = dir;
        _vaultPassword = pw;
        _openedContent = null;
        _loading = true;
      });
    }

    final files = await VaultService.listVaultFiles(dir);
    if (mounted) {
      setState(() {
        _files = files;
        _loading = false;
      });
    }
    // Store to recent list
    await RecentVaultsService.add(dir);
    await _loadRecent();
  }

  Future<void> _onCreateVault() async {
    try {
      final dir = await getDirectoryPath();
      if (dir == null) return;
      if (!mounted) return;
      final pw = await promptForPassword(
        context,
        title: 'Set a password for this vault',
      );
      if (pw == null || pw.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _vaultDir = dir;
        _vaultPassword = pw;
        _files = [];
        _openedContent = null;
      });
      // Store to recent list
      await RecentVaultsService.add(dir);
      await _loadRecent();
    } catch (e) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadRecent() async {
    final list = await RecentVaultsService.getRecent();
    if (!mounted) return;
    setState(() => _recentVaults = list);
  }

  void _onCloseVault() {
    setState(() {
      _vaultDir = null;
      _vaultPassword = null;
      _files = [];
      _openedContent = null;
      _dirty = false;
    });
    _editorController.clear();
  }

  Future<void> _onShowRecentVaults() async {
    if (_recentVaults.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No recent vaults found')));
      return;
    }

    final String? selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recent Vaults'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _recentVaults.length,
            itemBuilder: (context, index) {
              final path = _recentVaults[index];
              final displayName = RecentVaultsService.displayName(path);
              return ListTile(
                title: Text(displayName),
                subtitle: Text(
                  path,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => Navigator.of(context).pop(path),
                leading: const Icon(Icons.folder),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedPath != null) {
      await _onOpenRecent(selectedPath);
    }
  }

  Future<void> _onOpenFile(VaultFileEntry file) async {
    if (_vaultPassword == null) return;
    if (_dirty) {
      await _onSaveCurrentFile();
    }
    setState(() {
      _loading = true;
    });
    try {
      // Check cache before reading/decrypting
      final fp = await VaultService.getFingerprint(file.fullPath);
      final cached = ContentCache.instance.getIfFresh(file.fullPath, fp);
      if (cached != null) {
        setState(() {
          _openedContent = DecryptedFileContent(content: cached, source: file);
          _editorController.text = cached;
          _editorController.selection = TextSelection.collapsed(
            offset: cached.length,
          );
          _dirty = false;
          _loading = false;
        });
        return;
      }

      final bytes = await VaultService.readVaultFileBytes(file.fullPath);
      String text;
      if (bytes.isEmpty) {
        text = '';
      } else {
        // Offload decryption to a background isolate for responsiveness
        text = await CryptoWorker.decryptToString(
          data: bytes,
          password: _vaultPassword!,
        );
      }
      setState(() {
        _openedContent = DecryptedFileContent(content: text, source: file);
        _editorController.text = text;
        _editorController.selection = TextSelection.collapsed(
          offset: text.length,
        );
        _dirty = false;
        _loading = false;
      });
      // Update cache
      final fp2 = await VaultService.getFingerprint(file.fullPath);
      ContentCache.instance.put(file.fullPath, text, fp2);
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to decrypt: $e')));
      }
    }
  }

  Future<void> _onCreateNewFile() async {
    if (_vaultDir == null || _vaultPassword == null) return;

    final name = await promptForFilename(context);
    if (name == null || name.trim().isEmpty) return;

    setState(() {
      _loading = true;
    });

    try {
      // Create file with empty content
      final Uint8List encrypted = await CryptoService.encryptString(
        content: '',
        password: _vaultPassword!,
      );

      final entry = await VaultService.writeVaultFileBytes(
        dirPath: _vaultDir!,
        fileNameWithoutExt: name,
        encryptedBytes: encrypted,
      );
      final files = await VaultService.listVaultFiles(_vaultDir!);
      setState(() {
        _files = files;
        _openedContent = DecryptedFileContent(content: '', source: entry);
        _editorController.text = '';
        _editorController.selection = const TextSelection.collapsed(offset: 0);
        _dirty = false;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  Future<void> _onSaveCurrentFile() async {
    final current = _openedContent;
    final pw = _vaultPassword;
    if (current == null || pw == null) return;
    final updatedText = _editorController.text;

    setState(() {
      _loading = true;
    });

    try {
      // Offload encryption to background isolate
      final encrypted = await CryptoWorker.encryptString(
        content: updatedText,
        password: pw,
      );
      await VaultService.overwriteVaultFileBytes(
        fullPath: current.source.fullPath,
        encryptedBytes: encrypted,
      );
      setState(() {
        _openedContent = DecryptedFileContent(
          content: updatedText,
          source: current.source,
        );
        _dirty = false;
        _loading = false;
      });
      // Refresh cache with new fingerprint
      final fp = await VaultService.getFingerprint(current.source.fullPath);
      ContentCache.instance.put(current.source.fullPath, updatedText, fp);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${current.source.fileName}')),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  void _handleSaveShortcut() {
    if (_vaultPassword != null &&
        !_loading &&
        _openedContent != null &&
        _dirty) {
      _onSaveCurrentFile();
    }
  }

  Future<void> _onRenameFile(VaultFileEntry file) async {
    final dir = _vaultDir;
    if (dir == null) return;
    final currentNameNoExt = file.fileName.replaceAll(
      RegExp(r'\.fva$', caseSensitive: false),
      '',
    );
    final newName = await promptForFilename(
      context,
      title: 'Rename file',
      label: 'New name (without extension)',
      initialValue: currentNameNoExt,
    );
    if (newName == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    setState(() => _loading = true);
    try {
      final updated = await VaultService.renameVaultFile(
        fullPath: file.fullPath,
        newFileNameWithoutExt: trimmed,
      );
      final files = await VaultService.listVaultFiles(dir);
      setState(() {
        _files = files;
        // If currently open, update source path and title
        if (_openedContent?.source.fullPath == file.fullPath) {
          _openedContent = DecryptedFileContent(
            content: _openedContent!.content,
            source: updated,
          );
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to rename: $e')));
      }
    }
  }

  Future<void> _onDeleteFile(VaultFileEntry file) async {
    final dir = _vaultDir;
    if (dir == null) return;
    final confirm = await confirmDeletion(context, fileName: file.fileName);
    if (!confirm) return;
    setState(() => _loading = true);
    try {
      await VaultService.deleteVaultFile(file.fullPath);
      final files = await VaultService.listVaultFiles(dir);
      setState(() {
        _files = files;
        if (_openedContent?.source.fullPath == file.fullPath) {
          _openedContent = null;
          _editorController.text = '';
          _dirty = false;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }
}
