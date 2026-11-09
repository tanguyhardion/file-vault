import 'package:material_ui/material_ui.dart';

import '../../services/cloud/cloud_auth.dart';
import '../../services/offline/sync_status.dart';
import '../../services/offline/vault_repository.dart';
import '../dialogs/dialog_wrapper.dart';
import '../dialogs/progress_dialogs.dart';

/// App bar button showing whether the vaults are synced; tapping syncs now.
class SyncStatusButton extends StatelessWidget {
  final VaultRepository repository;

  const SyncStatusButton({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final status = repository.status;
    return ListenableBuilder(
      listenable: status,
      builder: (context, _) {
        final (icon, message) = _describe(status);
        return IconButton(
          tooltip: message,
          icon: status.syncing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Badge(
                  isLabelVisible: status.pendingChanges > 0,
                  label: Text('${status.pendingChanges}'),
                  child: Icon(icon),
                ),
          onPressed: status.syncing ? null : () => _syncNow(context),
        );
      },
    );
  }

  Future<void> _syncNow(BuildContext context) async {
    await repository.syncAll();
    if (!context.mounted) return;
    final (_, message) = _describe(repository.status);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static (IconData, String) _describe(SyncStatus s) {
    final pending = s.pendingChanges;
    final waiting = pending == 1
        ? '1 change waiting to sync'
        : '$pending changes waiting to sync';
    if (!s.online) {
      return (
        Icons.cloud_off_outlined,
        pending > 0
            ? "Offline: $waiting. It's sent when you're back online."
            : 'Offline: showing the vaults saved on this device.',
      );
    }
    if (s.syncing) return (Icons.sync, 'Syncing...');
    if (s.error != null) {
      return (Icons.sync_problem_outlined, 'Sync failed: ${s.error}');
    }
    if (pending > 0) return (Icons.cloud_upload_outlined, waiting);
    return (Icons.cloud_done_outlined, 'Synced. Vaults are available offline.');
  }
}

/// Signs out after syncing. If changes still couldn't be uploaded (e.g.
/// offline), asks before discarding them. Returns false if the user stayed.
///
/// [beforeSignOut] runs once the user is committed to signing out.
Future<bool> signOutAndForgetDevice(
  BuildContext context, {
  required CloudAuth auth,
  required VaultRepository repository,
  Future<void> Function()? beforeSignOut,
}) async {
  showLoadingDialog(context, message: 'Syncing...');
  final pending = await repository.syncBeforeSignOut();
  if (!context.mounted) return false;
  Navigator.of(context).pop(); // loading dialog

  if (pending > 0) {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogWrapper(
        title: const Text('Unsynced changes'),
        content: Text(
          '${pending == 1 ? '1 file has' : '$pending files have'} changes '
          "that aren't on the server yet${repository.status.online ? '' : " (you're offline)"}. "
          'Signing out removes them from this device.',
        ),
        cancelText: 'Stay signed in',
        confirmText: 'Sign out anyway',
        isDestructive: true,
        onCancel: () => Navigator.of(ctx).pop(false),
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (discard != true) return false;
  }

  await beforeSignOut?.call();
  // The offline copy is only ciphertext, but it belongs to the account.
  await repository.deleteLocalCopy();
  await auth.signOut();
  return true;
}
