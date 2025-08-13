import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'dialog_wrapper.dart';
import '../../services/backup_service.dart';

class BackupDialogResult {
  final String selectedPath;

  BackupDialogResult({required this.selectedPath});
}

Future<BackupDialogResult?> showBackupDialog(
  BuildContext context, {
  required String vaultName,
}) async {
  return await showDialog<BackupDialogResult>(
    context: context,
    builder: (ctx) => _BackupDialog(vaultName: vaultName),
  );
}

class _BackupDialog extends StatefulWidget {
  final String vaultName;

  const _BackupDialog({required this.vaultName});

  @override
  State<_BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<_BackupDialog> {
  String? _selectedPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackupPath();
  }

  Future<void> _loadLastBackupPath() async {
    final lastPath = await BackupPathsService.getLastBackupPath();
    if (lastPath != null && mounted) {
      final suggestedFilePath = BackupPathsService.generateBackupFileName(
        widget.vaultName, 
        lastPath,
      );
      setState(() {
        _selectedPath = suggestedFilePath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogWrapper(
      title: Text('Backup Vault "${widget.vaultName}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose where to save the backup:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedPath ?? 'No path selected',
                    style: TextStyle(
                      color: _selectedPath != null
                          ? Theme.of(context).textTheme.bodyMedium?.color
                          : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isLoading ? null : _selectPath,
                  child: const Text('Browse'),
                ),
              ],
            ),
          ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Recommended: Save to a cloud-synced folder (e.g. OneDrive, iCloud). Your backups consist only of encrypted data.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Creating backup...'),
          ],
        ],
      ),
      onCancel: _isLoading ? null : () => Navigator.of(context).pop(),
      onConfirm: _isLoading || _selectedPath == null
          ? null
          : () {
              Navigator.of(context).pop(
                BackupDialogResult(selectedPath: _selectedPath!),
              );
            },
      confirmText: 'Backup',
    );
  }

  Future<void> _selectPath() async {
    // Get the last backup path to use as initial directory
    final lastBackupPath = await BackupPathsService.getLastBackupPath();
    
    final result = await getSaveLocation(
      suggestedName: '${widget.vaultName}_backup_${DateTime.now().toIso8601String().split('T')[0]}.zip',
      initialDirectory: lastBackupPath,
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'ZIP files',
          extensions: ['zip'],
        ),
      ],
    );

    if (result != null) {
      setState(() {
        _selectedPath = result.path;
      });
    }
  }

  void setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }
}
