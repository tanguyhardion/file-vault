import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';
import '../mobile_app_state.dart';
import '../../services/storage/vault_storage.dart';
import '../../services/vault_session.dart';
import 'file_editor_screen.dart';

class VaultFilesScreen extends StatefulWidget {
  final MobileAppState appState;
  final VaultSession session;

  const VaultFilesScreen({
    super.key,
    required this.appState,
    required this.session,
  });

  @override
  State<VaultFilesScreen> createState() => _VaultFilesScreenState();
}

class _VaultFilesScreenState extends State<VaultFilesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  VaultSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _searchController.dispose();
    // Leaving the vault (back button) locks it.
    widget.appState.lock();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (_session.isLocked) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() {});
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future<void> _refresh() async {
    try {
      await _session.refresh();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _withLoading(
    String message,
    Future<void> Function() action,
  ) async {
    showLoadingDialog(context, message: message);
    Object? error;
    try {
      await action();
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (error != null) _showError(error);
  }

  Future<void> _openFile(VaultItem file) async {
    OpenedVaultFile? opened;
    await _withLoading('Decrypting...', () async {
      opened = await _session.openFile(file);
    });
    if (opened != null && mounted) await _pushEditor(opened!);
  }

  Future<void> _pushEditor(OpenedVaultFile opened) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FileEditorScreen(
          appState: widget.appState,
          session: _session,
          opened: opened,
        ),
      ),
    );
  }

  Future<void> _createFile() async {
    final name = await promptForName(context, title: 'New file');
    if (name == null || name.trim().isEmpty || !mounted) return;
    OpenedVaultFile? created;
    await _withLoading('Creating file...', () async {
      created = await _session.createFile(name.trim());
    });
    if (created != null && mounted) await _pushEditor(created!);
  }

  Future<void> _renameFile(VaultItem file) async {
    final newName = await promptForName(
      context,
      title: 'Rename file',
      label: 'New name (without extension)',
      initialValue: _displayName(file),
    );
    if (newName == null || newName.trim().isEmpty || !mounted) return;
    await _withLoading('Renaming...', () async {
      await _session.renameFile(file, newName.trim());
    });
  }

  Future<void> _deleteFile(VaultItem file) async {
    final confirm = await confirmDeletion(context, fileName: file.name);
    if (!confirm || !mounted) return;
    await _withLoading('Deleting...', () async {
      await _session.deleteFile(file);
    });
  }

  static String _displayName(VaultItem file) =>
      file.name.replaceAll(RegExp(r'\.fva$', caseSensitive: false), '');

  @override
  Widget build(BuildContext context) {
    final files = _session.files
        .where((f) => f.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_session.vault.name),
        actions: [
          IconButton(
            tooltip: 'Lock vault',
            icon: const Icon(Icons.lock_outline),
            onPressed: widget.appState.lock,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search file names',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New file',
        onPressed: _createFile,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: files.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No files in this vault'
                            : 'No matches',
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: files.length,
                itemBuilder: (context, i) {
                  final file = files[i];
                  return ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(_displayName(file)),
                    subtitle: file.lastModified == null
                        ? null
                        : Text(_formatDate(file.lastModified!.toLocal())),
                    onTap: () => _openFile(file),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'rename') _renameFile(file);
                        if (v == 'delete') _deleteFile(file);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
