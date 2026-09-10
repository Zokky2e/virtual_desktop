import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import '../../core/constants.dart';
import '../../core/di/injector.dart';
import '../../core/error/failure.dart';
import '../../core/models/file_item.dart';
import '../../core/repositories/file_system_repository.dart';
import '../../core/repositories/file_transfer_repository.dart';
import 'file_item_actions.dart';

/// What a file or folder icon carries while it is being dragged.
///
/// A [FileItem] knows its parent's id but not its name, and the
/// confirmation a drop asks for names both ends of the move. The view the
/// icon is shown in does know it, so the name travels with the drag
/// instead of being looked up once the drop lands.
class DraggedFileItem {
  const DraggedFileItem({required this.item, this.sourceFolderName});

  final FileItem item;

  /// Display name of the folder [item] is being dragged out of — "Desktop"
  /// or "Shared" at the two tree roots. Null when the view can't know it:
  /// search results come from anywhere in the tree.
  final String? sourceFolderName;
}

/// Whether dropping [item] into [folderId], in a view whose shared-ness is
/// [isSharedDestination], would leave it where it already is.
///
/// Parent ids alone can't answer this: both tree roots are null, so a
/// shared-root item dropped on the personal desktop would look like it was
/// already there.
bool isAlreadyInFolder({
  required FileItem item,
  required String? folderId,
  required bool isSharedDestination,
}) =>
    !isCrossTreeTransfer(
      item: item,
      isSharedDestination: isSharedDestination,
    ) &&
    item.parentFolderId == folderId;

/// Moves a dropped item into [destinationFolderId] once the user confirms.
///
/// Every drop is a move — inside one tree, or between the personal and
/// shared trees — and nothing is sent until the user says so. Nothing moves
/// optimistically either: the icon never left its place (what followed the
/// pointer was only drag feedback), so Cancel leaves the item exactly where
/// it was.
///
/// A drop onto the folder the item is already in isn't a move, and returns
/// without asking. Reordering within a folder is the caller's to handle
/// before getting here, and so is refusing a folder dropped into its own
/// subtree, which only the caller has the ancestry to see.
Future<void> confirmAndMoveDroppedItem({
  required BuildContext context,
  required DraggedFileItem dragged,
  required String? destinationFolderId,
  required String destinationFolderName,
  required bool isSharedDestination,

  /// The destination tree's repository. Only used when the move stays
  /// inside that tree — neither tree's repository can reach the other, so
  /// a move that crosses goes through [transferRepository].
  required FileSystemRepository fileSystemRepository,

  /// Defaults to the single unnamed registration, as in
  /// [pasteClipboardItem].
  FileTransferRepository? transferRepository,
}) async {
  final item = dragged.item;
  if (isAlreadyInFolder(
    item: item,
    folderId: destinationFolderId,
    isSharedDestination: isSharedDestination,
  )) {
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Move item'),
      content: Text.rich(_moveQuestion(dragged, destinationFolderName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Move'),
        ),
      ],
    ),
  );
  // Dismissing the dialog — Escape, a click outside it — is a Cancel too.
  if (confirmed != true) return;

  final Either<Failure, Object> result =
      isCrossTreeTransfer(item: item, isSharedDestination: isSharedDestination)
      ? await (transferRepository ?? getIt<FileTransferRepository>()).transfer(
          itemId: item.id,
          fromShared: item.ownerId == sharedOwnerId,
          toShared: isSharedDestination,
          destinationParentFolderId: destinationFolderId,
          mode: FileTransferMode.move,
        )
      : await fileSystemRepository.move(item.id, destinationFolderId);

  result.match((failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Move failed: ${failure.message}')),
      );
    }
  }, (_) {});
}

TextSpan _moveQuestion(DraggedFileItem dragged, String destinationFolderName) {
  const bold = TextStyle(fontWeight: FontWeight.bold);
  final sourceFolderName = dragged.sourceFolderName;
  return TextSpan(
    children: [
      const TextSpan(text: 'Move '),
      TextSpan(text: dragged.item.name, style: bold),
      if (sourceFolderName != null) ...[
        const TextSpan(text: ' from '),
        TextSpan(text: sourceFolderName, style: bold),
      ],
      const TextSpan(text: ' to '),
      TextSpan(text: destinationFolderName, style: bold),
      const TextSpan(text: '?'),
    ],
  );
}
