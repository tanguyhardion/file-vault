import 'package:material_ui/material_ui.dart';

import '../../services/storage/vault_storage.dart';
import '../../services/vault_session.dart';
import 'file_item_menu.dart';

class FileList extends StatelessWidget {
  final List<VaultItem> files;
  final OpenedVaultFile? openedContent;
  final int? hoveredIndex;
  final ValueChanged<int?> onHoverChanged;
  final void Function(VaultItem) onOpenFile;
  final void Function(VaultItem) onRename;
  final void Function(VaultItem) onDelete;

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
        final isOpen = openedContent?.item.id == f.id;
        final isHovered = hoveredIndex == index;
        return MouseRegion(
          onEnter: (_) => onHoverChanged(index),
          onExit: (_) => onHoverChanged(null),
          child: ListTile(
            selected: isOpen,
            title: Text(f.name),
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
