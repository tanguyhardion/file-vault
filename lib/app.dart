import 'dart:io';

import 'package:flutter/material.dart';

import 'mobile/mobile_root.dart';
import 'screens/vault_home_page.dart';

class FileVaultApp extends StatelessWidget {
  const FileVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Vault',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      // Desktop works on local (OneDrive-synced) folders; Android talks to
      // OneDrive directly.
      home: Platform.isAndroid ? const MobileRoot() : const VaultHomePage(),
    );
  }
}
