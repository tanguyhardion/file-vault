
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/vault_models.dart';
import '../services/vault_service.dart';

class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key});

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  final _service = VaultService();
  bool _busy = false;
  String? _status;

  Future<void> _createVault() async {
    setState(() {
      _busy = true;
      _status = 'Selecting folder to encrypt...';
    });
    try {
      // Pick a folder to encrypt
      final dir = await getDirectoryPath(confirmButtonText: 'Select Folder');
      if (dir == null) {
        setState(() {
          _busy = false;
          _status = 'Cancelled';
        });
        return;
      }

      // Ask for password
      final password = await _promptForPassword(context, title: 'Create Vault Password');
      if (password == null || password.isEmpty) {
        setState(() {
          _busy = false;
          _status = 'No password entered';
        });
        return;
      }

      // Collect entries
      setState(() => _status = 'Reading files...');
      final entries = await _service.collectEntriesFromDirectory(dir);

      // Choose save location
      final suggestedName = p.basename(dir).isEmpty ? 'vault' : p.basename(dir);
      final file = await getSaveLocation(
        acceptedTypeGroups: [
          XTypeGroup(label: 'File Vault', extensions: [kVaultFileExtension]),
        ],
        suggestedName: '$suggestedName.$kVaultFileExtension',
        confirmButtonText: 'Create',
      );
      if (file == null) {
        setState(() {
          _busy = false;
          _status = 'Cancelled';
        });
        return;
      }

      setState(() => _status = 'Encrypting...');
      await _service.saveVault(vaultPath: file.path, entries: entries, password: password);
      setState(() {
        _busy = false;
        _status = 'Vault created: ${file.path}';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _openVault() async {
    setState(() {
      _busy = true;
      _status = 'Selecting .fva file...';
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(label: 'File Vault', extensions: [kVaultFileExtension]),
        ],
      );
      if (file == null) {
        setState(() {
          _busy = false;
          _status = 'Cancelled';
        });
        return;
      }

      final password = await _promptForPassword(context, title: 'Enter Vault Password');
      if (password == null || password.isEmpty) {
        setState(() {
          _busy = false;
          _status = 'No password entered';
        });
        return;
      }

      setState(() => _status = 'Decrypting...');
      final entries = await _service.loadVault(vaultPath: file.path, password: password);

      // Choose extraction folder
      final dir = await getDirectoryPath(confirmButtonText: 'Extract Here');
      if (dir == null) {
        setState(() {
          _busy = false;
          _status = 'Cancelled';
        });
        return;
      }

      setState(() => _status = 'Extracting files...');
      final count = await _service.extractEntriesToDirectory(entries, dir);
      setState(() {
        _busy = false;
        _status = 'Extracted $count files to $dir';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<String?> _promptForPassword(BuildContext context, {required String title}) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (ok == true) return ctrl.text;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Wrap(
          spacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _createVault,
              icon: const Icon(Icons.lock),
              label: const Text('Create Vault (.fva)'),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _openVault,
              icon: const Icon(Icons.lock_open),
              label: const Text('Open Vault (.fva)'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_busy) const CircularProgressIndicator(),
        if (_status != null) Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(_status!, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
