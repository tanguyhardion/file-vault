class VaultService {
  VaultService._();

  static const fvaExtension = '.fva';

  /// File name with the `.fva` extension, safe to extract from a backup on
  /// Windows.
  static String fileNameFor(String nameWithoutExt) =>
      '${sanitizeFileName(nameWithoutExt)}$fvaExtension';

  static bool isVaultFileName(String name) =>
      name.toLowerCase().endsWith(fvaExtension);

  /// Makes a file name safe for Windows/OneDrive (no extension handling).
  static String sanitizeFileName(String input) {
    var name = input.trim();
    if (name.isEmpty) name = 'untitled';
    // Basic invalid chars for Windows and others
    const invalid = ['\\', '/', ':', '*', '?', '"', '<', '>', '|'];
    for (final ch in invalid) {
      name = name.replaceAll(ch, '_');
    }
    // Remove trailing dots/spaces
    name = name.replaceAll(RegExp(r'[ .]+$'), '');
    return name.isEmpty ? 'untitled' : name;
  }
}
