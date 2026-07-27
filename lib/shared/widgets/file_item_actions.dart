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

Future<void> showFileItemContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required FileItem item,
}) async {
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
    await _showRenameDialog(context, item);
  } else if (selection == 'copy') {
    clipboard.copy(item);
  } else if (selection == 'cut') {
    clipboard.cut(item);
  } else if (selection == 'delete') {
    await _confirmAndDelete(context, item);
  }
}

Future<void> _showRenameDialog(BuildContext context, FileItem item) async {
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
  await getIt<FileSystemRepository>().rename(item.id, newName);
  if (context.mounted) {
    context.read<WindowBloc>().add(WindowTitleChanged(item.id, newName));
  }
}

Future<void> _confirmAndDelete(BuildContext context, FileItem item) async {
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

  final repo = getIt<FileSystemRepository>();
  if (item.isFolder) {
    await repo.deleteFolder(item.id);
  } else {
    await repo.deleteFile(item.id);
  }
}

Future<String> _resolveCopyName({
  required String ownerId,
  required String? parentFolderId,
  required String baseName,
}) async {
  final repo = getIt<FileSystemRepository>();
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
}) async {
  final clipboardState = clipboard.state;
  if (clipboardState.isEmpty) return;

  final item = clipboardState.item!;
  final repo = getIt<FileSystemRepository>();

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

  // Copy mode — folders aren't duplicated recursively in this pass (that's
  // a meaningfully bigger feature: walking the whole subtree). For now,
  // copy is file-only; attempting to copy a folder is a silent no-op with
  // a snackbar explaining why, rather than a half-correct shallow copy.
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
    ownerId: item.ownerId,
    parentFolderId: destinationFolderId,
    baseName: item.name,
  );

  final storageService = getIt<StorageService>();
  final downloadResult = await storageService.downloadFile(item.storageKey!);

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
      final uploadResult = await storageService.uploadFile(
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
