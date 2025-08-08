import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'models/vault_models.dart';
import 'services/crypto_service.dart';
import 'services/vault_service.dart';
import 'widgets/dialogs.dart';

void main() {
  runApp(const FileVaultApp());
}

class FileVaultApp extends StatelessWidget {
  const FileVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const VaultHomePage(),
    );
  }
}

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
            const _SaveIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(
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
      // ...existing code...
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
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final f = _files[index];
        final isOpen = _openedContent?.source.fullPath == f.fullPath;
        return ListTile(
          selected: isOpen,
          title: Text(f.fileName),
          onTap: () => _onOpenFile(f),
          leading: const Icon(Icons.insert_drive_file_outlined),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            content.source.fileName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Tooltip(
                message: 'Save (Ctrl+S)',
                child: FilledButton.icon(
                  onPressed: (_vaultPassword != null && !_loading && _dirty)
                      ? _onSaveCurrentFile
                      : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              if (_dirty)
                const Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: Colors.orange),
                    SizedBox(width: 6),
                    Text('Unsaved changes'),
                  ],
                )
              else
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    SizedBox(width: 6),
                    Text('Saved'),
                  ],
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
      final pw = await promptForPassword(
        context,
        title: 'Set a password for this vault',
      );
      if (pw == null || pw.isEmpty) return;

      setState(() {
        _vaultDir = dir;
        _vaultPassword = pw;
        _files = [];
        _openedContent = null;
      });
    } catch (e) {
      setState(() {});
    }
  }

  Future<void> _onOpenFile(VaultFileEntry file) async {
    if (_vaultPassword == null) return;
    setState(() {
      _loading = true;
    });
    try {
      final bytes = await VaultService.readVaultFileBytes(file.fullPath);
      final text = await CryptoService.decryptToString(
        data: bytes,
        password: _vaultPassword!,
      );
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

    final content = await promptForText(
      context,
      title: 'New file content',
      label: 'Content',
    );
    if (content == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final Uint8List encrypted = await CryptoService.encryptString(
        content: content,
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
        _openedContent = DecryptedFileContent(content: content, source: entry);
        _editorController.text = content;
        _editorController.selection = TextSelection.collapsed(
          offset: content.length,
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
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
