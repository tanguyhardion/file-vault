import 'package:flutter/material.dart';

import '../../services/storage/vault_storage.dart';
import '../mobile_app_state.dart';
import '../../services/vault_session.dart';

enum _ConflictChoice { keepEditing, reload, overwrite }

enum _LeaveChoice { save, discard }

class FileEditorScreen extends StatefulWidget {
  final MobileAppState appState;
  final VaultSession session;
  final OpenedVaultFile opened;

  const FileEditorScreen({
    super.key,
    required this.appState,
    required this.session,
    required this.opened,
  });

  @override
  State<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<FileEditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _controller;
  late OpenedVaultFile _opened;
  bool _dirty = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _opened = widget.opened;
    _controller = TextEditingController(text: _opened.content);
    WidgetsBinding.instance.addObserver(this);
    widget.appState.beforeLock = _saveQuietly;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.appState.beforeLock == _saveQuietly) {
      widget.appState.beforeLock = null;
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android may kill a backgrounded app; don't leave edits only in memory.
    if (state == AppLifecycleState.hidden) _saveQuietly();
  }

  String get _title =>
      _opened.item.name.replaceAll(RegExp(r'\.fva$', caseSensitive: false), '');

  void _onChanged(String _) {
    widget.appState.userActivity();
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Saves without prompting; on conflict the edits stay dirty in memory and
  /// the user resolves it on the next explicit save.
  Future<void> _saveQuietly() async {
    if (!_dirty || _busy || widget.session.isLocked) return;
    try {
      await _upload(overwrite: false);
    } catch (_) {
      // Ignored; the file stays marked as unsaved.
    }
  }

  Future<void> _upload({required bool overwrite}) async {
    final text = _controller.text;
    setState(() => _busy = true);
    try {
      final saved = await widget.session.save(
        _opened,
        text,
        overwrite: overwrite,
      );
      _opened = saved;
      // Only clear the flag if nothing was typed while uploading.
      if (mounted && _controller.text == text) setState(() => _dirty = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Returns true if the content is now saved.
  Future<bool> _save() async {
    try {
      await _upload(overwrite: false);
      _snack('Saved');
      return true;
    } on FileChangedExternallyException {
      return _resolveConflict();
    } catch (e) {
      _snack('Failed to save: $e');
      return false;
    }
  }

  Future<bool> _resolveConflict() async {
    if (!mounted) return false;
    final choice = await showDialog<_ConflictChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File changed elsewhere'),
        content: const Text(
          'This file was modified on another device after you opened it.\n\n'
          'Reload to get the latest version (your edits here are lost), or '
          'overwrite it with your version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ConflictChoice.keepEditing),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ConflictChoice.reload),
            child: const Text('Reload'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, _ConflictChoice.overwrite),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
    switch (choice) {
      case _ConflictChoice.reload:
        await _reload();
        return !_dirty;
      case _ConflictChoice.overwrite:
        try {
          await _upload(overwrite: true);
          _snack('Saved');
          return true;
        } catch (e) {
          _snack('Failed to save: $e');
          return false;
        }
      case _ConflictChoice.keepEditing:
      case null:
        return false;
    }
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    try {
      final fresh = await widget.session.openFile(_opened.item);
      _opened = fresh;
      _controller.text = fresh.content;
      if (mounted) setState(() => _dirty = false);
    } catch (e) {
      _snack('Failed to reload: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReload() async {
    if (_dirty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Reloading replaces your unsaved edits.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reload'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _reload();
  }

  Future<void> _onBack() async {
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save your changes before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == _LeaveChoice.save && !await _save()) return;
    if (mounted) Navigator.of(context).pop();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Flexible(child: Text(_title, overflow: TextOverflow.ellipsis)),
              if (_dirty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.circle, size: 10, color: Colors.orange),
              ],
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
              onPressed: _busy ? null : _confirmReload,
            ),
            IconButton(
              tooltip: 'Save',
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              onPressed: (_dirty && !_busy) ? _save : null,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _controller,
              expands: true,
              maxLines: null,
              minLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              // Ask the keyboard not to learn from vault contents.
              enableIMEPersonalizedLearning: false,
              decoration: const InputDecoration(border: InputBorder.none),
              style: const TextStyle(fontFamily: 'monospace'),
              onChanged: _onChanged,
            ),
          ),
        ),
      ),
    );
  }
}
