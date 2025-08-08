class VaultFileEntry {
  final String fileName; // with .fva extension
  final String fullPath; // absolute

  const VaultFileEntry({required this.fileName, required this.fullPath});
}

class DecryptedFileContent {
  final String content; // UTF-8 text only for this app
  final VaultFileEntry source;

  const DecryptedFileContent({required this.content, required this.source});
}
