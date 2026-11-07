import 'package:flutter/material.dart';

import '../controllers/vault_home_page_controller.dart';
import '../services/cloud/cloud_vaults.dart';

mixin VaultEventHandlers<T extends StatefulWidget> on State<T> {
  VaultHomePageController get controller;

  Future<void> onOpenVault() async {
    try {
      await controller.openVault(context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> onOpenVaultFromList(CloudVault vault) async {
    try {
      await controller.openVaultAt(vault, context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> onImportVault() async {
    try {
      await controller.importVault(context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import: $e')));
      }
    }
  }

  Future<void> onSignOut() async {
    try {
      await controller.signOut(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> onCreateVault() async {
    try {
      await controller.createVault(context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> onOpenFile(dynamic file) async {
    try {
      await controller.openFile(file, context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to decrypt: $e')));
      }
    }
  }

  Future<void> onCreateNewFile() async {
    try {
      await controller.createNewFile(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  Future<void> onRenameFile(dynamic file) async {
    try {
      await controller.renameFile(context, file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to rename: $e')));
      }
    }
  }

  Future<void> onDeleteFile(dynamic file) async {
    try {
      await controller.deleteFile(context, file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> onBackupVault() async {
    try {
      final success = await controller.backupVault(context);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vault backup created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to backup: $e')));
      }
    }
  }

  Future<void> onAutoBackupSettings() async {
    try {
      await controller.showAutoBackupSettings(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $e')),
        );
      }
    }
  }

  Future<void> onAppSettings() async {
    try {
      await controller.showAppSettings(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $e')),
        );
      }
    }
  }
}
