import 'package:flutter/widgets.dart';

class SaveIntent extends Intent {
  const SaveIntent();
}

class OpenVaultIntent extends Intent {
  const OpenVaultIntent();
}

class ShowRecentVaultsIntent extends Intent {
  const ShowRecentVaultsIntent();
}

class CreateVaultIntent extends Intent {
  const CreateVaultIntent();
}

class BackupVaultIntent extends Intent {
  const BackupVaultIntent();
}

class AutoBackupSettingsIntent extends Intent {
  const AutoBackupSettingsIntent();
}

class CloseVaultIntent extends Intent {
  const CloseVaultIntent();
}
