import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../services/vault_marker.dart';
import '../saved_vaults_store.dart';

/// Browses folders on the phone's storage and returns the selected vault.
class LocalFolderPickerScreen extends StatefulWidget {
  final String rootPath;

  const LocalFolderPickerScreen({super.key, required this.rootPath});

  @override
  State<LocalFolderPickerScreen> createState() =>
      _LocalFolderPickerScreenState();
}

class _LocalFolderPickerScreenState extends State<LocalFolderPickerScreen> {
  late final List<String> _stack = [widget.rootPath];
  List<String> _folders = [];
  bool _isVault = false;
  bool _loading = true;
  Object? _error;

  String get _current => _stack.last;

  String get _title =>
      _stack.length == 1 ? 'Phone storage' : p.basename(_current);

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
      final folders = <String>[];
      var isVault = false;
      await for (final ent in Directory(_current).list(followLinks: false)) {
        final name = p.basename(ent.path);
        if (ent is Directory && !name.startsWith('.')) folders.add(ent.path);
        if (ent is File && name == VaultMarker.fileName) isVault = true;
      }
      folders.sort(
        (a, b) => p
            .basename(a)
            .toLowerCase()
            .compareTo(p.basename(b).toLowerCase()),
      );
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _isVault = isVault;
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

  void _enter(String folder) {
    _stack.add(folder);
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
        location: VaultLocation.local,
        id: _current,
        name: p.basename(_current),
        path: _current,
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
          title: Text(_title),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _current,
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
                    label: Text('Use "${p.basename(_current)}" as vault'),
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
              title: Text(p.basename(folder)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _enter(folder),
            ),
        ],
      ),
    );
  }
}
