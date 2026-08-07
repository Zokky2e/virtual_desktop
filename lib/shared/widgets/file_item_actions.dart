import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/features/file-system/clipboard/file_clipboard_cubit.dart';
import 'package:virtual_desktop/features/file-system/clipboard/file_clipboard_state.dart';
import 'package:virtual_desktop/features/windows/bloc/window_bloc.dart';
import 'package:virtual_desktop/features/windows/bloc/window_event.dart';
import 'package:virtual_desktop/shared/utils/mime_utils.dart';
import '../../core/di/injector.dart';
import '../../core/models/file_item.dart';
import '../../core/repositories/file_system_repository.dart';
import '../../core/services/storage_service.dart';

/// Sentinel owner_id the server uses for the shared tree — mirrors
/// app/constants.py's SHARED_OWNER_ID. Used only to guard against
/// pasting an item into a tree it doesn't belong to (see
/// pasteClipboardItem below); the two trees don't support cross-tree
/// move/copy.
const _sharedOwnerId = 'shared';

Future<void> showFileItemContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required FileItem item,

  /// Defaults to the personal-tree repository via getIt when null — pass
  /// the 'shared'-named instance when this menu is opened on an item
  /// inside the Shared folder window.
  FileSystemRepository? fileSystemRepository,
}) async {
  final repo = fileSystemRepository ?? getIt<FileSystemRepository>();
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
        const PopupMenuItem(value: 'copy', child: Text('Copy')),
      const PopupMenuItem(value: 'cut', child: Text('Cut')),
      const PopupMenuItem(value: 'delete', child: Text('Delete')),
    ],
  );

  if (selection == null || !context.mounted) return;

  if (selection == 'rename') {
    await _showRenameDialog(context, item, repo);
  } else if (selection == 'copy') {
    clipboard.copy(item);
  } else if (selection == 'cut') {
    clipboard.cut(item);
  } else if (selection == 'delete') {
    await _confirmAndDelete(context, item, repo);
  }
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
    candidate = suffix == 2
        ? '$stem (copy)$extension'
        : '$stem (copy $suffix)$extension';
  }
}

Future<void> pasteClipboardItem({
  required BuildContext context,
  required FileClipboardCubit clipboard,
  required String? destinationFolderId,

  /// Repository/service the paste operation runs against. Defaults to
  /// the personal-tree instances when null.
  FileSystemRepository? fileSystemRepository,
  StorageService? storageService,

  /// Whether [destinationFolderId] lives in the shared tree. Used only to
  /// reject pasting an item across trees — the backend doesn't support
  /// moving/copying an item between a user's own tree and the shared one
  /// (they're different owner_id scopes server-side).
  bool isSharedDestination = false,
}) async {
  final clipboardState = clipboard.state;
  if (clipboardState.isEmpty) return;

  final item = clipboardState.item!;

  final itemIsShared = item.ownerId == _sharedOwnerId;
  if (itemIsShared != isSharedDestination) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Moving or copying between personal and shared folders isn't "
            'supported yet.',
          ),
        ),
      );
    }
    clipboard.clear();
    return;
  }

  final repo = fileSystemRepository ?? getIt<FileSystemRepository>();
  final storage = storageService ?? getIt<StorageService>();

  if (clipboardState.mode == ClipboardMode.cut) {
    // Pasting into the same folder it's already in is a no-op.
    if (item.parentFolderId == destinationFolderId) {
      clipboard.clear();
      return;
    }
    await repo.move(item.id, destinationFolderId);
    clipboard.clear();
    return;
  }

  // Copy mode — folders still aren't duplicated recursively (see
  // original docstring); this applies equally to the shared tree.
  if (item.isFolder) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copying folders isn\'t supported yet — only files.'),
        ),
      );
    }
    return;
  }

  final resolvedName = await _resolveCopyName(
    repo: repo,
    ownerId: item.ownerId,
    parentFolderId: destinationFolderId,
    baseName: item.name,
  );

  final downloadResult = await storage.downloadFile(item.storageKey!);

  await downloadResult.match(
    (failure) async {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copy failed: ${failure.message}')),
        );
      }
    },
    (bytes) async {
      final newStorageKey =
          'users/${item.ownerId}/${DateTime.now().millisecondsSinceEpoch}_$resolvedName';
      final uploadResult = await storage.uploadFile(
        bytes: bytes,
        path: newStorageKey,
        mimeType: mimeTypeForFileName(resolvedName),
      );
      await uploadResult.match(
        (failure) async {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copy failed: ${failure.message}')),
            );
          }
        },
        (path) async {
          await repo.createFile(
            name: resolvedName,
            parentFolderId: destinationFolderId,
            ownerId: item.ownerId,
            type: item.type,
            storageKey: path,
            size: bytes.length,
          );
        },
      );
    },
  );
}
