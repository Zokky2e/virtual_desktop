import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/features/preview/presentation/preview_window_content.dart';
import 'package:virtual_desktop/features/windows/bloc/window_bloc.dart';
import 'package:virtual_desktop/features/windows/bloc/window_event.dart';
import 'package:virtual_desktop/features/windows/presentation/folder_window_content.dart';
import '../../../core/models/file_item.dart';
import '../bloc/desktop_bloc.dart';
import '../bloc/desktop_event.dart';

class DesktopIcon extends StatelessWidget {
  const DesktopIcon({
    super.key,
    required this.item,
    required this.isSelected,
    this.onFolderDoubleTap,
    this.iconColor = Colors.white,
  });

  /// When non-null, double-tapping a folder calls this instead of opening
  /// a brand-new window — used when this icon is rendered *inside* an
  /// already-open folder window (see FolderWindowContent), so navigating
  /// deeper reuses that window rather than spawning another one.
  final VoidCallback? onFolderDoubleTap;
  final FileItem item;
  final bool isSelected;
  final Color iconColor;

  IconData get _iconData {
    switch (item.type) {
      case FileItemType.folder:
        return Icons.folder;
      case FileItemType.image:
        return Icons.image;
      case FileItemType.video:
        return Icons.movie;
      case FileItemType.audio:
        return Icons.audiotrack;
      case FileItemType.pdf:
        return Icons.picture_as_pdf;
      case FileItemType.text:
        return Icons.description;
      case FileItemType.json:
        return Icons.data_object;
      case FileItemType.markdown:
        return Icons.article;
      case FileItemType.other:
        return Icons.insert_drive_file;
    }
  }

  void _handleDoubleTap(BuildContext context) {
    if (item.isFolder) {
      if (onFolderDoubleTap != null) {
        onFolderDoubleTap!();
        return;
      }
      // Opened from the desktop (root) — open a new folder-browsing window.
      context.read<WindowBloc>().add(
        WindowOpened(
          id: item.id,
          title: item.name,
          contentBuilder: (context) => FolderWindowContent(
            key: ValueKey('folder-content-${item.id}'),
            windowId: item.id,
            rootFolder: item,
          ),
        ),
      );
      return;
    }

    context.read<WindowBloc>().add(
      WindowOpened(
        id: item.id,
        title: item.name,
        contentBuilder: (context) => PreviewWindowContent(
          key: ValueKey('preview-content-${item.id}'),
          item: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Stop the tap from bubbling to the desktop's clear-selection handler.
        final desktopBloc = context.read<DesktopBloc?>();
        desktopBloc?.add(DesktopIconSelected(item.id));
      },
      onDoubleTap: () {
        _handleDoubleTap(context);
      },
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconData, size: 40, color: iconColor),
            const SizedBox(height: 4),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: iconColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
