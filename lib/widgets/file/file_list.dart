import 'package:flutter/material.dart';

import '../../models/vault_models.dart';
import 'file_item_menu.dart';

class FileList extends StatelessWidget {
  final List<VaultFileEntry> files;
  final DecryptedFileContent? openedContent;
  final int? hoveredIndex;
  final ValueChanged<int?> onHoverChanged;
  final void Function(VaultFileEntry) onOpenFile;
  final void Function(VaultFileEntry) onRename;
  final void Function(VaultFileEntry) onDelete;

  const FileList({
    super.key,
    required this.files,
    required this.openedContent,
    required this.hoveredIndex,
    required this.onHoverChanged,
    required this.onOpenFile,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(child: Text('No secret files in this vault'));
    }
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final f = files[index];
        final isOpen = openedContent?.source.fullPath == f.fullPath;
        final isHovered = hoveredIndex == index;
        return MouseRegion(
          onEnter: (_) => onHoverChanged(index),
          onExit: (_) => onHoverChanged(null),
          child: ListTile(
            selected: isOpen,
            title: Text(f.fileName),
            onTap: () => onOpenFile(f),
            leading: const Icon(Icons.insert_drive_file_outlined),
            trailing: isHovered
                ? Transform.translate(
                    offset: const Offset(8.0, 0),
                    child: FileItemMenu(
                      onOpen: () {},
                      onClose: () => onHoverChanged(null),
                      onRename: () => onRename(f),
                      onDelete: () => onDelete(f),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
