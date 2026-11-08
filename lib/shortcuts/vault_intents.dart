import 'package:flutter/widgets.dart';

class SaveIntent extends Intent {
  const SaveIntent();
}

class OpenVaultIntent extends Intent {
  const OpenVaultIntent();
}

class ImportVaultIntent extends Intent {
  const ImportVaultIntent();
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

class AppSettingsIntent extends Intent {
  const AppSettingsIntent();
}
