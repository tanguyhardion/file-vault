import 'package:flutter/material.dart';

enum _MenuAction { rename, delete }

class FileItemMenu extends StatelessWidget {
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const FileItemMenu({
    super.key,
    required this.onOpen,
    required this.onClose,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnCtx) => IconButton(
        tooltip: 'More',
        icon: const Icon(Icons.more_vert),
        onPressed: () async {
          onOpen();
          final RenderBox button = btnCtx.findRenderObject() as RenderBox;
          final RenderBox overlay =
              Overlay.of(btnCtx).context.findRenderObject() as RenderBox;
          final RelativeRect position = RelativeRect.fromRect(
            Rect.fromPoints(
              button.localToGlobal(Offset.zero, ancestor: overlay),
              button.localToGlobal(
                button.size.bottomRight(Offset.zero),
                ancestor: overlay,
              ),
            ),
            Offset.zero & overlay.size,
          );

          final selected = await showMenu<_MenuAction>(
            context: btnCtx,
            position: position,
            items: const [
              PopupMenuItem(
                value: _MenuAction.rename,
                child: Row(
                  children: [
                    Icon(Icons.drive_file_rename_outline),
                    SizedBox(width: 8),
                    Text('Rename'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          );

          try {
            if (selected == _MenuAction.rename) {
              onRename();
            } else if (selected == _MenuAction.delete) {
              onDelete();
            }
          } finally {
            onClose();
          }
        },
      ),
    );
  }
}
