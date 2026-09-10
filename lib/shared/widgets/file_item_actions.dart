import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:virtual_desktop/features/file-system/clipboard/file_clipboard_cubit.dart';
import 'package:virtual_desktop/features/file-system/clipboard/file_clipboard_state.dart';
import 'package:virtual_desktop/features/windows/bloc/window_bloc.dart';
import 'package:virtual_desktop/features/windows/bloc/window_event.dart';
import 'package:virtual_desktop/shared/utils/browser_download.dart';
import 'package:virtual_desktop/shared/utils/mime_utils.dart';
import '../../core/constants.dart';
import '../../core/di/injector.dart';
import '../../core/error/failure.dart';
import '../../core/models/file_item.dart';
import '../../core/repositories/file_system_repository.dart';
import '../../core/repositories/file_transfer_repository.dart';
import '../../core/services/storage_service.dart';
import 'operation_feedback.dart';

/// Whether moving [item] into a view whose shared-ness is
/// [isSharedDestination] would cross between the two trees.
///
/// The trees are different owner_id scopes, so `move()` on the
/// destination view's repository 404s for an item from the other one.
/// Paste and drop (confirmAndMoveDroppedItem) both check this up front
/// and route a crossing through [FileTransferRepository] instead.
bool isCrossTreeTransfer({
  required FileItem item,
  required bool isSharedDestination,
}) => (item.ownerId == sharedOwnerId) != isSharedDestination;

Future<void> showFileItemContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required FileItem item,

  /// Defaults to the personal-tree repository via getIt when null — pass
  /// the 'shared'-named instance when this menu is opened on an item
  /// inside the Shared folder window.
  FileSystemRepository? fileSystemRepository,

  /// Same defaulting as [fileSystemRepository]. Used by Download.
  StorageService? storageService,
}) async {
  final repo = fileSystemRepository ?? getIt<FileSystemRepository>();
  final storage = storageService ?? getIt<StorageService>();
  final clipboard = context.read<FileClipboardCubit>();
  final selection = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    ),
    items: [
      const PopupMenuItem(value: 'rename', child: Text('Rename')),
      if (!item.isFolder)
        const PopupMenuItem(value: 'download', child: Text('Download')),
      if (!item.isFolder)
        const PopupMenuItem(value: 'copy', child: Text('Copy')),
      const PopupMenuItem(value: 'cut', child: Text('Cut')),
      const PopupMenuItem(value: 'delete', child: Text('Delete')),
    ],
  );

  if (selection == null || !context.mounted) return;

  if (selection == 'rename') {
    await _showRenameDialog(context, item, repo);
  } else if (selection == 'download') {
    await _downloadItem(context, item, storage);
  } else if (selection == 'copy') {
    clipboard.copy(item);
  } else if (selection == 'cut') {
    clipboard.cut(item);
  } else if (selection == 'delete') {
    await _confirmAndDelete(context, item, repo);
  }
}

/// Saves [item] to the user's machine.
///
/// This is the only entry point to triggerBrowserDownload — a browser
/// Blob download on web, a native Save As dialog on Windows. CLAUDE.md
/// lists downloads as one of the three genuine web/Windows divergences,
/// but nothing in the UI ever reached it, so the whole
/// browser_download* trio was describing a feature the user could not
/// invoke.
Future<void> _downloadItem(
  BuildContext context,
  FileItem item,
  StorageService storage,
) async {
  final storageKey = item.storageKey;
  if (storageKey == null) return;

  final result = await storage.downloadFile(storageKey);
  await result.match((failure) async {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${failure.message}')),
      );
    }
  }, (bytes) => triggerBrowserDownload(bytes, item.name));
}

Future<void> _showRenameDialog(
  BuildContext context,
  FileItem item,
  FileSystemRepository repo,
) async {
  final controller = TextEditingController(text: item.name);
  final newName = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rename'),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
  if (newName == null || newName.isEmpty || newName == item.name) return;
  await repo.rename(item.id, newName);
  if (context.mounted) {
    context.read<WindowBloc>().add(WindowTitleChanged(item.id, newName));
  }
}

Future<void> _confirmAndDelete(
  BuildContext context,
  FileItem item,
  FileSystemRepository repo,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete item'),
      content: Text('Move "${item.name}" to the Recycle Bin?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  if (item.isFolder) {
    await repo.deleteFolder(item.id);
  } else {
    await repo.deleteFile(item.id);
  }
}

Future<String> _resolveCopyName({
  required FileSystemRepository repo,
  required String ownerId,
  required String? parentFolderId,
  required String baseName,
}) async {
  final dotIndex = baseName.lastIndexOf('.');
  final stem = dotIndex > 0 ? baseName.substring(0, dotIndex) : baseName;
  final extension = dotIndex > 0 ? baseName.substring(dotIndex) : '';

  var candidate = baseName;
  var suffix = 1;
  while (true) {
    final existsResult = await repo.nameExistsInFolder(
      ownerId: ownerId,
      parentFolderId: parentFolderId,
      name: candidate,
    );
    final exists = existsResult.getOrElse((_) => false);
    if (!exists) return candidate;
    suffix++;
    // suffix counts attempts, so the printed number is suffix - 1: the
    // sequence is name, name (copy), name (copy 2), name (copy 3). It
    // used to print `suffix` directly and jump straight from "(copy)" to
    // "(copy 3)".
    candidate = suffix == 2
        ? '$stem (copy)$extension'
        : '$stem (copy ${suffix - 1})$extension';
  }
}

/// Paste that lands in the other tree.
///
/// Runs server-side via POST /desktop/transfer rather than
/// download-then-upload through the client: these are the same
/// multi-gigabyte videos the Range-streaming endpoints exist for, and on
/// web a round trip would mean holding one entirely in memory.
///
/// A copy resolves its name against the destination folder first, so
/// pasting twice yields "report (copy).pdf" exactly as a within-tree
/// paste does. A cut keeps the item's own name; the server 409s on a
/// clash, and that message is surfaced.
Future<Either<Failure, Unit>> _pasteAcrossTrees({
  required FileItem item,
  required bool isCut,
  required String? destinationFolderId,
  required bool isSharedDestination,
  required FileSystemRepository destinationRepo,
  required FileTransferRepository transferRepository,
}) async {
  final resolvedName = isCut
      ? null
      : await _resolveCopyName(
          repo: destinationRepo,
          ownerId: isSharedDestination ? sharedOwnerId : item.ownerId,
          parentFolderId: destinationFolderId,
          baseName: item.name,
        );

  final result = await transferRepository.transfer(
    itemId: item.id,
    fromShared: item.ownerId == sharedOwnerId,
    toShared: isSharedDestination,
    destinationParentFolderId: destinationFolderId,
    mode: isCut ? FileTransferMode.move : FileTransferMode.copy,
    name: resolvedName,
  );
  return result.map((_) => unit);
}

/// Copy inside one tree. The bytes come down to the client and go back up
/// under a name that doesn't clash, which is why a large file takes a
/// while.
Future<Either<Failure, Unit>> _copyWithinTree({
  required FileItem item,
  required String? destinationFolderId,
  required FileSystemRepository repo,
  required StorageService storage,
}) async {
  final resolvedName = await _resolveCopyName(
    repo: repo,
    ownerId: item.ownerId,
    parentFolderId: destinationFolderId,
    baseName: item.name,
  );

  final downloaded = await storage.downloadFile(item.storageKey!);
  return downloaded.match<Future<Either<Failure, Unit>>>(
    (failure) async => Left(failure),
    (bytes) async {
      // fileName and parentFolderId are what the API provider's upload
      // endpoint actually reads — it creates the tree record together with
      // the bytes. Omitting them sent a null parent and let the service
      // fall back to the tail of a caller-built path, so the copy landed
      // at the root of the tree named `1712345678901_report.pdf` and the
      // resolvedName de-duplication above was thrown away.
      final uploaded = await storage.uploadFile(
        bytes: bytes,
        fileName: resolvedName,
        mimeType: mimeTypeForFileName(resolvedName),
        ownerId: item.ownerId,
        parentFolderId: destinationFolderId,
      );
      return uploaded.match<Future<Either<Failure, Unit>>>(
        (failure) async => Left(failure),
        (path) async {
          final created = await repo.createFile(
            name: resolvedName,
            parentFolderId: destinationFolderId,
            ownerId: item.ownerId,
            type: item.type,
            storageKey: path,
            size: bytes.length,
          );
          return created.map((_) => unit);
        },
      );
    },
  );
}

Future<void> pasteClipboardItem({
  required BuildContext context,
  required FileClipboardCubit clipboard,
  required String? destinationFolderId,

  /// Display name of the destination, for the progress and outcome
  /// messages. Without it they leave the destination out.
  String? destinationFolderName,

  /// Repository/service the paste operation runs against. Defaults to
  /// the personal-tree instances when null.
  FileSystemRepository? fileSystemRepository,
  StorageService? storageService,

  /// Whether [destinationFolderId] lives in the shared tree. A paste
  /// that crosses the boundary is routed through [transferRepository]
  /// instead of the ordinary same-tree move/copy.
  bool isSharedDestination = false,

  /// Handles the cross-tree case. Defaults to the single unnamed
  /// registration — unlike the repository and service above there is no
  /// per-tree variant, because a transfer spans both.
  FileTransferRepository? transferRepository,
}) async {
  final clipboardState = clipboard.state;
  if (clipboardState.isEmpty) return;

  final item = clipboardState.item!;
  final isCut = clipboardState.mode == ClipboardMode.cut;
  final crossesTrees = isCrossTreeTransfer(
    item: item,
    isSharedDestination: isSharedDestination,
  );

  final repo = fileSystemRepository ?? getIt<FileSystemRepository>();
  final storage = storageService ?? getIt<StorageService>();
  final messenger = ScaffoldMessenger.maybeOf(context);

  final Future<Either<Failure, Unit>> Function() operation;
  if (crossesTrees) {
    final transfers = transferRepository ?? getIt<FileTransferRepository>();
    operation = () => _pasteAcrossTrees(
      item: item,
      isCut: isCut,
      destinationFolderId: destinationFolderId,
      isSharedDestination: isSharedDestination,
      destinationRepo: repo,
      transferRepository: transfers,
    );
  } else if (isCut) {
    // Pasting into the same folder it's already in is a no-op.
    if (item.parentFolderId == destinationFolderId) {
      clipboard.clear();
      return;
    }
    operation = () => repo.move(item.id, destinationFolderId);
  } else {
    // Copy mode — folders still aren't duplicated recursively (see
    // original docstring); this applies equally to the shared tree.
    if (item.isFolder) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Copying folders isn\'t supported yet — only files.'),
        ),
      );
      return;
    }
    operation = () => _copyWithinTree(
      item: item,
      destinationFolderId: destinationFolderId,
      repo: repo,
      storage: storage,
    );
  }

  final label = destinationFolderName == null
      ? item.name
      : '${item.name} to $destinationFolderName';
  final result = await runWithProgressFeedback<Unit>(
    messenger: messenger,
    inProgress: '${isCut ? 'Moving' : 'Copying'} $label…',
    succeeded: '${isCut ? 'Moved' : 'Copied'} $label',
    failurePrefix: isCut ? 'Move failed' : 'Copy failed',
    operation: operation,
  );

  // Cut is consumed by a paste that worked; copy stays on the clipboard so
  // it can be pasted again. A cut that failed stays too, so it can be
  // retried rather than silently dropped.
  if (isCut && result.isRight()) clipboard.clear();
}
