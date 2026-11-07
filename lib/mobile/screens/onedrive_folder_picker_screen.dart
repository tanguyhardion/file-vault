import 'package:flutter/material.dart';

import '../../services/vault_marker.dart';
import '../onedrive/onedrive_client.dart';
import '../saved_vaults_store.dart';

/// Browses OneDrive folders and returns the selected vault folder.
class OneDriveFolderPickerScreen extends StatefulWidget {
  final OneDriveClient client;

  const OneDriveFolderPickerScreen({super.key, required this.client});

  @override
  State<OneDriveFolderPickerScreen> createState() =>
      _OneDriveFolderPickerScreenState();
}

class _Crumb {
  final String id;
  final String name;
  const _Crumb(this.id, this.name);
}

class _OneDriveFolderPickerScreenState
    extends State<OneDriveFolderPickerScreen> {
  final List<_Crumb> _stack = [const _Crumb('root', 'OneDrive')];
  List<DriveItem> _folders = [];
  bool _isVault = false;
  bool _loading = true;
  Object? _error;

  _Crumb get _current => _stack.last;

  String get _path => _stack.length == 1
      ? '/'
      : '/${_stack.skip(1).map((c) => c.name).join('/')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final children = await widget.client.listChildren(_current.id);
      final folders = children.where((c) => c.isFolder).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _isVault = children.any(
          (c) => !c.isFolder && c.name == VaultMarker.fileName,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _enter(DriveItem folder) {
    _stack.add(_Crumb(folder.id, folder.name));
    _load();
  }

  bool _goUp() {
    if (_stack.length <= 1) return false;
    _stack.removeLast();
    _load();
    return true;
  }

  void _select() {
    Navigator.of(context).pop(
      SavedVault(
        location: VaultLocation.oneDrive,
        id: _current.id,
        name: _current.name,
        path: _path,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stack.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goUp();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_current.name),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _path,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ),
        body: _buildBody(),
        bottomNavigationBar: _isVault && !_loading
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: _select,
                    icon: const Icon(Icons.lock_open),
                    label: Text('Use "${_current.name}" as vault'),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (_isVault)
            const ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('This folder is a vault'),
            ),
          if (_folders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No subfolders')),
            ),
          for (final folder in _folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _enter(folder),
            ),
        ],
      ),
    );
  }
}
