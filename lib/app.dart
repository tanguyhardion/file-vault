import 'package:flutter/material.dart';

import 'screens/vault_home_page.dart';

class FileVaultApp extends StatelessWidget {
  const FileVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Vault',
      debugShowCheckedModeBanner: false,
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
      home: const VaultHomePage(),
    );
  }
}
