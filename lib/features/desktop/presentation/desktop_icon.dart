import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/features/preview/presentation/preview_window_content.dart';
import 'package:virtual_desktop/features/windows/bloc/window_bloc.dart';
import 'package:virtual_desktop/features/windows/bloc/window_event.dart';
import 'package:virtual_desktop/features/windows/presentation/folder_window_content.dart';
import 'package:virtual_desktop/shared/widgets/file_item_actions.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../../core/services/storage_service.dart';
import '../bloc/desktop_bloc.dart';
import '../bloc/desktop_event.dart';

class DesktopIcon extends StatelessWidget {
  const DesktopIcon({
    super.key,
    required this.item,
    required this.isSelected,
    this.onFolderDoubleTap,
    this.iconColor = Colors.white,
    this.fileSystemRepository,
    this.storageService,
  });

  /// When non-null, double-tapping a folder calls this instead of opening
  /// a brand-new window — used when this icon is rendered *inside* an
  /// already-open folder window (see FolderWindowContent), so navigating
  /// deeper reuses that window rather than spawning another one.
  final VoidCallback? onFolderDoubleTap;
  final FileItem item;
  final bool isSelected;
  final Color iconColor;

  /// Repository/service this icon's actions (context menu, preview) use.
  /// Null means "use the default personal-tree instances" — set by
  /// callers rendering items from another tree, e.g. the Shared window.
  final FileSystemRepository? fileSystemRepository;
  final StorageService? storageService;

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
      case FileItemType.subtitle:
        return Icons.subtitles;
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
            fileSystemRepository: fileSystemRepository,
            storageService: storageService,
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
          storageService: storageService,
          fileSystemRepository: fileSystemRepository,
        ),
      ),
    );
  }

  Widget _visual(BuildContext context, {required bool selected}) {
    return Tooltip(
      message: item.name,
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconData, size: 32, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: iconColor,
                fontSize: 12,
                shadows: const [
                  Shadow(
                    color: Color.fromARGB(115, 0, 0, 0),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                  Shadow(color: Colors.black54, blurRadius: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = GestureDetector(
      onTap: () {
        final desktopBloc = context.read<DesktopBloc?>();
        desktopBloc?.add(DesktopIconSelected(item.id));
      },
      onDoubleTap: () => _handleDoubleTap(context),
      onSecondaryTapDown: (details) {
        final desktopBloc = context.read<DesktopBloc?>();
        desktopBloc?.add(DesktopIconSelected(item.id));
        showFileItemContextMenu(
          context: context,
          globalPosition: details.globalPosition,
          item: item,
          fileSystemRepository: fileSystemRepository,
        );
      },
      child: _visual(context, selected: isSelected),
    );
    return Draggable<FileItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.85, child: _visual(context, selected: false)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: interactive),
      child: interactive,
    );
  }
}
