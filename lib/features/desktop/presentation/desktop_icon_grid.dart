// lib/features/desktop/presentation/desktop_icon_grid.dart
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import '../../../core/di/injector.dart';
import '../../../core/error/failure.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../../shared/utils/sort_index.dart';
import '../../../shared/widgets/file_item_actions.dart';
import 'desktop_icon.dart';

/// Renders [items] as a wrap of draggable icons that can be reordered
/// within [containerFolderId] (null = desktop root), or receive items
/// dragged in from another folder or the desktop.
///
/// This is the one place that turns a drop into either a
/// [FileSystemRepository.move] (crossing folders — appended to the end,
/// same as your existing cut/paste move) or a
/// [FileSystemRepository.reorder] (same folder, positioned where dropped).
///
/// Only [DesktopPage] mounts this today — FolderWindowContent builds its own
/// Wrap of [DesktopIcon]s. [fileSystemRepository] exists so it *can* be
/// reused for the shared tree (the FolderWindowContent injection pattern):
/// without it, every drop would resolve the unnamed personal registration and
/// a shared item would be moved via the caller's own uid, which 404s.
class DesktopIconGrid extends StatelessWidget {
  const DesktopIconGrid({
    super.key,
    required this.items,
    required this.containerFolderId,
    this.selectedItemIds = const {},
    this.onFolderDoubleTap,
    this.iconColor = Colors.white,
    this.fileSystemRepository,
    this.isSharedTree = false,
  });

  final List<FileItem> items;
  final String? containerFolderId;
  final Set<String> selectedItemIds;
  final void Function(FileItem folder)? onFolderDoubleTap;
  final Color iconColor;

  /// Tree these drops act on. Defaults to the unnamed (personal)
  /// registration, so DesktopPage is unaffected.
  final FileSystemRepository? fileSystemRepository;

  /// Whether this grid is showing the shared tree. Only used to reject a
  /// drop coming from the other tree — [fileSystemRepository] is what
  /// actually decides which tree an accepted drop acts on.
  final bool isSharedTree;

  FileSystemRepository get _repo =>
      fileSystemRepository ?? getIt<FileSystemRepository>();

  Future<void> _dropBefore(
    BuildContext context,
    FileItem dragged,
    FileItem? before,
  ) async {
    if (dragged.id == before?.id) return;
    if (_rejectCrossTree(context, dragged)) return;

    final repo = _repo;

    if (dragged.parentFolderId != containerFolderId) {
      final result = await repo.move(dragged.id, containerFolderId);
      if (context.mounted) _reportFailure(context, result);
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

    final result = await repo.reorder(
      itemId: dragged.id,
      newSortIndex: sortIndexBetween(prev, next),
    );
    if (context.mounted) _reportFailure(context, result);
    assert(before == null || beforeIndex != -1);
  }

  Future<void> _dropInto(
    BuildContext context,
    FileItem dragged,
    FileItem folder,
  ) async {
    if (dragged.id == folder.id) return;
    if (_rejectCrossTree(context, dragged)) return;
    final result = await _repo.move(dragged.id, folder.id);
    if (context.mounted) _reportFailure(context, result);
  }

  /// True when the drop was refused. Checked before any request goes out:
  /// dragging a shared item onto the personal desktop (or the reverse)
  /// used to issue a move() that 404'd, which read as the drag simply not
  /// working.
  bool _rejectCrossTree(BuildContext context, FileItem dragged) {
    if (!isCrossTreeTransfer(
      item: dragged,
      isSharedDestination: isSharedTree,
    )) {
      return false;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text(crossTreeTransferMessage)));
    return true;
  }

  /// Drops used to swallow their result: a `move` that 404'd or a `reorder`
  /// the backend doesn't implement just made the icon snap back with no
  /// explanation. Say so instead.
  void _reportFailure(BuildContext context, Either<Failure, Unit> result) {
    result.match((failure) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text(failure.message)));
    }, (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<FileItem>(
      onAcceptWithDetails: (details) =>
          _dropBefore(context, details.data, null),
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
                onDropBefore: (dragged) => _dropBefore(context, dragged, item),
                onDropInto: item.isFolder
                    ? (dragged) => _dropInto(context, dragged, item)
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
