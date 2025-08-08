import 'dart:convert';

/// File extension for vault archives
const String kVaultFileExtension = 'fva'; // File Vault Archive

/// Magic header and versioning for the .fva file format
class VaultMagic {
  static const List<int> magicBytes = [0x46, 0x56, 0x41, 0x01]; // 'FVA' + v1
}

/// Simple metadata stored in cleartext header (non-sensitive)
class VaultHeaderMeta {
  final String app; // e.g., "File Vault"
  final int createdAtEpochMs;

  VaultHeaderMeta({required this.app, required this.createdAtEpochMs});

  Map<String, dynamic> toJson() => {
        'app': app,
        'createdAt': createdAtEpochMs,
      };

  static VaultHeaderMeta fromJson(Map<String, dynamic> json) => VaultHeaderMeta(
        app: json['app'] as String? ?? 'File Vault',
        createdAtEpochMs: (json['createdAt'] as num?)?.toInt() ?? 0,
      );

  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));

  static VaultHeaderMeta fromBytes(List<int> bytes) =>
      fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
}

/// Entry descriptor in the encrypted payload
class VaultEntry {
  final String path; // relative path inside archive
  final List<int> data; // raw file bytes (before compression)

  VaultEntry({required this.path, required this.data});

  Map<String, dynamic> toJson() => {
        'path': path,
        'data': base64.encode(data),
      };

  static VaultEntry fromJson(Map<String, dynamic> json) => VaultEntry(
        path: json['path'] as String,
        data: base64.decode(json['data'] as String),
      );
}

/// The encrypted content structure (before encryption)
class VaultPayload {
  final List<VaultEntry> entries;

  VaultPayload({required this.entries});

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  static VaultPayload fromJson(Map<String, dynamic> json) => VaultPayload(
        entries: ((json['entries'] as List?) ?? [])
            .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));

  static VaultPayload fromBytes(List<int> bytes) =>
      fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
}
