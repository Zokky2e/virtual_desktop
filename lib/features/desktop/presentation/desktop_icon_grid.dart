// lib/features/desktop/presentation/desktop_icon_grid.dart
import 'package:flutter/material.dart';
import '../../../core/di/injector.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../../shared/utils/sort_index.dart';
import 'desktop_icon.dart';

/// Renders [items] as a wrap of draggable icons that can be reordered
/// within [containerFolderId] (null = desktop root), or receive items
/// dragged in from another folder or the desktop.
///
/// This is the one place that turns a drop into either a
/// [FileSystemRepository.move] (crossing folders — appended to the end,
/// same as your existing cut/paste move) or a
/// [FileSystemRepository.reorder] (same folder, positioned where dropped).
/// DesktopPage and FolderWindowContent both delegate here instead of
/// duplicating the drop logic.
class DesktopIconGrid extends StatelessWidget {
  const DesktopIconGrid({
    super.key,
    required this.items,
    required this.containerFolderId,
    this.selectedItemIds = const {},
    this.onFolderDoubleTap,
    this.iconColor = Colors.white,
  });

  final List<FileItem> items;
  final String? containerFolderId;
  final Set<String> selectedItemIds;
  final void Function(FileItem folder)? onFolderDoubleTap;
  final Color iconColor;

  Future<void> _dropBefore(FileItem dragged, FileItem? before) async {
    if (dragged.id == before?.id) return;

    final repo = getIt<FileSystemRepository>();

    if (dragged.parentFolderId != containerFolderId) {
      await repo.move(dragged.id, containerFolderId);
      return;
    }

    final beforeIndex = before == null
        ? -1
        : items.indexWhere((i) => i.id == before.id);
    final siblingsExcludingDragged = items
        .where((i) => i.id != dragged.id)
        .toList();
    final insertAt = before == null
        ? siblingsExcludingDragged.length
        : siblingsExcludingDragged.indexWhere((i) => i.id == before.id);

    final prev = insertAt > 0
        ? siblingsExcludingDragged[insertAt - 1].sortIndex
        : null;
    final next = insertAt < siblingsExcludingDragged.length
        ? siblingsExcludingDragged[insertAt].sortIndex
        : null;

    await repo.reorder(
      itemId: dragged.id,
      newSortIndex: sortIndexBetween(prev, next),
    );
    assert(before == null || beforeIndex != -1);
  }

  Future<void> _dropInto(FileItem dragged, FileItem folder) async {
    if (dragged.id == folder.id) return;
    await getIt<FileSystemRepository>().move(dragged.id, folder.id);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<FileItem>(
      onAcceptWithDetails: (details) => _dropBefore(details.data, null),
      builder: (context, candidateData, rejectedData) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final item in items)
              _GridSlot(
                key: ValueKey('slot-${item.id}'),
                item: item,
                isSelected: selectedItemIds.contains(item.id),
                iconColor: iconColor,
                onFolderDoubleTap: item.isFolder && onFolderDoubleTap != null
                    ? () => onFolderDoubleTap!(item)
                    : null,
                onDropBefore: (dragged) => _dropBefore(dragged, item),
                onDropInto: item.isFolder
                    ? (dragged) => _dropInto(dragged, item)
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class _GridSlot extends StatelessWidget {
  const _GridSlot({
    super.key,
    required this.item,
    required this.isSelected,
    required this.iconColor,
    required this.onFolderDoubleTap,
    required this.onDropBefore,
    required this.onDropInto,
  });

  final FileItem item;
  final bool isSelected;
  final Color iconColor;
  final VoidCallback? onFolderDoubleTap;
  final void Function(FileItem dragged) onDropBefore;
  final void Function(FileItem dragged)? onDropInto;

  @override
  Widget build(BuildContext context) {
    return DragTarget<FileItem>(
      onWillAcceptWithDetails: (details) => details.data.id != item.id,
      onAcceptWithDetails: (details) {
        if (onDropInto != null) {
          onDropInto!(details.data);
        } else {
          onDropBefore(details.data);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: !isHovering
              ? null
              : item.isFolder
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                )
              : const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.white, width: 2),
                  ),
                ),
          child: DesktopIcon(
            item: item,
            isSelected: isSelected,
            iconColor: iconColor,
            onFolderDoubleTap: onFolderDoubleTap,
          ),
        );
      },
    );
  }
}
