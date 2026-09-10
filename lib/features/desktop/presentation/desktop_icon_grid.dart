// lib/features/desktop/presentation/desktop_icon_grid.dart
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import '../../../core/di/injector.dart';
import '../../../core/error/failure.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../../shared/utils/sort_index.dart';
import '../../../shared/widgets/file_item_drop.dart';
import 'desktop_icon.dart';

/// Renders [items] as a wrap of draggable icons that can be reordered
/// within [containerFolderId] (null = desktop root), or receive items
/// dragged in from another folder, from the other tree, or from search.
///
/// This is the one place that turns a drop here into either a move —
/// confirmed first by [confirmAndMoveDroppedItem], and appended to the end
/// the same as a cut/paste move — or a [FileSystemRepository.reorder]
/// (same folder, positioned where dropped, and not asked about: nothing
/// changes location).
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
    this.containerFolderName = 'Desktop',
    this.selectedItemIds = const {},
    this.onFolderDoubleTap,
    this.iconColor = Colors.white,
    this.fileSystemRepository,
    this.isSharedTree = false,
  });

  final List<FileItem> items;
  final String? containerFolderId;

  /// What the move confirmation calls [containerFolderId], and where an
  /// icon dragged out of this grid says it came from.
  final String containerFolderName;

  final Set<String> selectedItemIds;
  final void Function(FileItem folder)? onFolderDoubleTap;
  final Color iconColor;

  /// Tree these drops act on. Defaults to the unnamed (personal)
  /// registration, so DesktopPage is unaffected.
  final FileSystemRepository? fileSystemRepository;

  /// Whether this grid is showing the shared tree, which decides whether a
  /// drop crosses between trees. [fileSystemRepository] is still what serves
  /// a drop that doesn't.
  final bool isSharedTree;

  FileSystemRepository get _repo =>
      fileSystemRepository ?? getIt<FileSystemRepository>();

  Future<void> _dropBefore(
    BuildContext context,
    DraggedFileItem dragged,
    FileItem? before,
  ) async {
    final item = dragged.item;
    if (item.id == before?.id) return;

    if (!isAlreadyInFolder(
      item: item,
      folderId: containerFolderId,
      isSharedDestination: isSharedTree,
    )) {
      await _move(context, dragged, containerFolderId, containerFolderName);
      return;
    }

    final beforeIndex = before == null
        ? -1
        : items.indexWhere((i) => i.id == before.id);
    final siblingsExcludingDragged = items
        .where((i) => i.id != item.id)
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

    final result = await _repo.reorder(
      itemId: item.id,
      newSortIndex: sortIndexBetween(prev, next),
    );
    if (context.mounted) _reportFailure(context, result);
    assert(before == null || beforeIndex != -1);
  }

  Future<void> _dropInto(
    BuildContext context,
    DraggedFileItem dragged,
    FileItem folder,
  ) async {
    if (dragged.item.id == folder.id) return;
    await _move(context, dragged, folder.id, folder.name);
  }

  Future<void> _move(
    BuildContext context,
    DraggedFileItem dragged,
    String? destinationFolderId,
    String destinationFolderName,
  ) => confirmAndMoveDroppedItem(
    context: context,
    dragged: dragged,
    destinationFolderId: destinationFolderId,
    destinationFolderName: destinationFolderName,
    isSharedDestination: isSharedTree,
    fileSystemRepository: _repo,
  );

  /// A reorder used to swallow its result: one the backend doesn't
  /// implement just made the icon snap back with no explanation. Say so
  /// instead. (Moves report their own failures.)
  void _reportFailure(BuildContext context, Either<Failure, Unit> result) {
    result.match((failure) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text(failure.message)));
    }, (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<DraggedFileItem>(
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
                containerFolderName: containerFolderName,
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
    required this.containerFolderName,
    required this.isSelected,
    required this.iconColor,
    required this.onFolderDoubleTap,
    required this.onDropBefore,
    required this.onDropInto,
  });

  final FileItem item;
  final String containerFolderName;
  final bool isSelected;
  final Color iconColor;
  final VoidCallback? onFolderDoubleTap;
  final void Function(DraggedFileItem dragged) onDropBefore;
  final void Function(DraggedFileItem dragged)? onDropInto;

  bool _isSelf(DraggedFileItem dragged) => dragged.item.id == item.id;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DraggedFileItem>(
      // An icon let go over its own slot is accepted here and ignored, not
      // refused. Refused, it fell through to the grid's own target, which
      // took it for a drop past the last icon and quietly moved the item to
      // the end of the folder — for what was really a drag called off.
      onAcceptWithDetails: (details) {
        final dragged = details.data;
        if (_isSelf(dragged)) return;
        if (onDropInto != null) {
          onDropInto!(dragged);
        } else {
          onDropBefore(dragged);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.any(
          (dragged) => dragged != null && !_isSelf(dragged),
        );
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
            sourceFolderName: containerFolderName,
          ),
        );
      },
    );
  }
}
