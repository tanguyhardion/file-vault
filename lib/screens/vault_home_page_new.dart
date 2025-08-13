import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/vault_home_page_controller.dart';
import '../mixins/vault_event_handlers.dart';
import '../shortcuts/save_intent.dart';
import '../widgets/vault/vault_app_bar.dart';
import '../widgets/vault/vault_left_panel.dart';
import '../widgets/vault/vault_main_content.dart';

class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key});

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> with VaultEventHandlers {
  late final VaultHomePageController _controller;

  @override
  VaultHomePageController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller = VaultHomePageController();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
              _controller.handleSaveShortcut();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: VaultAppBar(
              controller: _controller,
              onOpenVault: onOpenVault,
              onShowRecentVaults: onShowRecentVaults,
              onCreateVault: onCreateVault,
              onBackupVault: onBackupVault,
              onAutoBackupSettings: onAutoBackupSettings,
            ),
            body: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      children: [
        // Left pane: file list
        VaultLeftPanel(
          controller: _controller,
          onOpenVaultInExplorer: onOpenVaultInExplorer,
          onCreateNewFile: onCreateNewFile,
          onOpenFile: onOpenFile,
          onRename: onRenameFile,
          onDelete: onDeleteFile,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: VerticalDivider(width: 1),
        ),
        // Main view
        Expanded(
          child: VaultMainContent(
            controller: _controller,
            onOpenRecent: onOpenRecent,
            onShowAllRecent: onShowRecentVaults,
          ),
        ),
      ],
    );
  }
}
