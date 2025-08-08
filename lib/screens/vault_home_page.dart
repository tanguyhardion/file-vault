import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../models/vault_models.dart';
import '../services/crypto_service.dart';
import '../services/vault_service.dart';
import '../widgets/dialogs.dart';
import '../shortcuts/save_intent.dart';

class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key});

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  String? _vaultDir;
  String? _vaultPassword; // kept in-memory only for session
  List<VaultFileEntry> _files = [];
  DecryptedFileContent? _openedContent;
  bool _loading = false;
  final TextEditingController _editorController = TextEditingController();
  bool _dirty = false;
  int? _hoveredIndex;
  int? _menuOpenIndex;

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
                IconButton(
                  tooltip: 'Open vault folder',
                  icon: const Icon(Icons.folder_open),
                  onPressed: _onOpenVault,
                ),
                IconButton(
                  tooltip: 'Create new vault',
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: _onCreateVault,
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
                      _buildVaultHeader(context),
                      Expanded(child: _buildFileList()),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          8,
                          8,
                          8,
                          24,
                        ), // more margin at bottom
                        child: FilledButton.icon(
                          onPressed:
                              (_vaultDir != null && _vaultPassword != null)
                                  ? _onCreateNewFile
                                  : null,
                          icon: const Icon(Icons.note_add),
                          label: const Text('New secret file'),
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
                          ? _buildEmptyState()
                          : _buildContentView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVaultHeader(BuildContext context) {
    final dir = _vaultDir;
    final name = dir == null ? 'No vault opened' : p.basename(dir);
    return ListTile(
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(dir ?? 'Open or create a vault'),
    );
  }

  Widget _buildFileList() {
    if (_vaultDir == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Open a vault folder to see .fva files'),
        ),
      );
    }
    if (_files.isEmpty) {
      return const Center(child: Text('No .fva files in this vault'));
    }
    return ListView.separated(
      itemCount: _files.length,
      separatorBuilder: (_, _) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        final f = _files[index];
        final isOpen = _openedContent?.source.fullPath == f.fullPath;
        final isHovered = _hoveredIndex == index || _menuOpenIndex == index;
        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) {
            // Don't hide while a menu for this item is open
            if (_menuOpenIndex != index) {
              setState(() => _hoveredIndex = null);
            }
          },
          child: ListTile(
            selected: isOpen,
            title: Text(f.fileName),
            onTap: () => _onOpenFile(f),
            leading: const Icon(Icons.insert_drive_file_outlined),
            trailing: isHovered
                ? _FileItemMenu(
                    onOpen: () => setState(() => _menuOpenIndex = index),
                    onClose: () => setState(() {
                      _menuOpenIndex = null;
                      _hoveredIndex = null;
                    }),
                    onRename: () => _onRenameFile(f),
                    onDelete: () => _onDeleteFile(f),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_outline, size: 56),
          SizedBox(height: 12),
          Text('Open a vault and select a file to view its content'),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    final content = _openedContent!;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            children: [
              Text(
                content.source.fileName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_dirty) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Unsaved changes',
                  child: Icon(Icons.circle, size: 10, color: Colors.orange),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Tooltip(
                message: 'Save (Ctrl+S)',
                child: FilledButton.icon(
                  onPressed:
                      (_vaultPassword != null && !_loading && _dirty)
                          ? _onSaveCurrentFile
                          : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _editorController,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              style: const TextStyle(fontFamily: 'monospace'),
              onChanged: (_) {
                if (!_dirty) {
                  setState(() => _dirty = true);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onOpenVault() async {
    try {
      final dir = await getDirectoryPath();
      if (!mounted || dir == null) return;

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
    } catch (e) {
      if (mounted) {
        setState(() {});
      }
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
      final bytes = await VaultService.readVaultFileBytes(file.fullPath);
      String text;
      if (bytes.isEmpty) {
        text = '';
      } else {
        text = await CryptoService.decryptToString(
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
      final encrypted = await CryptoService.encryptString(
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
    final currentNameNoExt = file.fileName.replaceAll(RegExp(r'\.fva$', caseSensitive: false), '');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename: $e')),
        );
      }
    }
  }

  Future<void> _onDeleteFile(VaultFileEntry file) async {
    final dir = _vaultDir;
    if (dir == null) return;
    final confirm = await confirmDeletion(
      context,
      fileName: file.fileName,
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}

class _FileItemMenu extends StatelessWidget {
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _FileItemMenu({
    required this.onOpen,
    required this.onClose,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnCtx) => IconButton(
        tooltip: 'More',
        icon: const Icon(Icons.more_vert),
        onPressed: () async {
          onOpen();
          final RenderBox button = btnCtx.findRenderObject() as RenderBox;
          final RenderBox overlay = Overlay.of(btnCtx).context.findRenderObject() as RenderBox;
          final RelativeRect position = RelativeRect.fromRect(
            Rect.fromPoints(
              button.localToGlobal(Offset.zero, ancestor: overlay),
              button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
            ),
            Offset.zero & overlay.size,
          );

          final selected = await showMenu<_MenuAction>(
            context: btnCtx,
            position: position,
            items: [
              const PopupMenuItem(
                value: _MenuAction.rename,
                child: Row(
                  children: [
                    Icon(Icons.drive_file_rename_outline),
                    SizedBox(width: 8),
                    Text('Rename'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: _MenuAction.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          );

          try {
            if (selected == _MenuAction.rename) {
              onRename();
            } else if (selected == _MenuAction.delete) {
              onDelete();
            }
          } finally {
            onClose();
          }
        },
      ),
    );
  }
}

enum _MenuAction { rename, delete }
