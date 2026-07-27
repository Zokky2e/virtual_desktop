import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/core/repositories/auth_repository.dart';
import 'package:virtual_desktop/core/services/storage_service.dart';
import 'package:virtual_desktop/features/file-system/bloc/upload_bloc.dart';
import 'package:virtual_desktop/features/file-system/bloc/upload_event.dart';
import 'package:virtual_desktop/features/file-system/bloc/upload_state.dart';
import 'package:virtual_desktop/features/file-system/clipboard/file_clipboard_cubit.dart';
import 'package:virtual_desktop/features/windows/bloc/window_state.dart';
import 'package:virtual_desktop/shared/utils/mime_utils.dart';
import 'package:virtual_desktop/shared/widgets/file_item_actions.dart';
import '../../../core/di/injector.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../windows/bloc/window_bloc.dart';
import '../../windows/bloc/window_event.dart';
import '../../desktop/presentation/desktop_icon.dart';

class FolderWindowContent extends StatefulWidget {
  const FolderWindowContent({
    super.key,
    required this.windowId,
    required this.rootFolder,
  });

  /// The WindowBloc id this content belongs to — needed to dispatch
  /// title/leading updates as the user navigates deeper or back.
  final String windowId;

  /// The folder this window was originally opened for.
  final FileItem rootFolder;

  @override
  State<FolderWindowContent> createState() => _FolderWindowContentState();
}

class _FolderWindowContentState extends State<FolderWindowContent> {
  // Stack of folders navigated into, root folder always at index 0.
  late final List<FileItem> _folderStack;

  @override
  void initState() {
    super.initState();
    _folderStack = [widget.rootFolder];
  }

  FileItem get _currentFolder => _folderStack.last;

  void _openSubfolder(FileItem folder) {
    setState(() => _folderStack.add(folder));
    _syncWindowChrome();
  }

  void _goBack() {
    if (_folderStack.length <= 1) return;
    setState(() => _folderStack.removeLast());
    _syncWindowChrome();
  }

  void _syncWindowChrome() {
    context.read<WindowBloc>().add(
      WindowChromeChanged(
        id: widget.windowId,
        title: _currentFolder.name,
        leadingBuilder: _folderStack.length > 1
            ? (context) => IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: _goBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            : null,
      ),
    );
  }

  Future<void> _createFolder() async {
    final uid = getIt<AuthRepository>().currentUser!.uid;
    await getIt<FileSystemRepository>().createFolder(
      name: 'New Folder',
      parentFolderId: _currentFolder.id,
      ownerId: uid,
    );
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file?.bytes == null || !mounted) return;
    context.read<UploadBloc>().add(
      UploadFileRequested(
        bytes: file!.bytes!,
        fileName: file.name,
        mimeType: mimeTypeForFileName(file.name),
        parentFolderId: _currentFolder.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UploadBloc(
        storageService: getIt<StorageService>(),
        fileSystemRepository: getIt<FileSystemRepository>(),
        authRepository: getIt<AuthRepository>(),
      ),
      child: BlocListener<UploadBloc, UploadState>(
        listener: (context, state) {
          if (state is UploadFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: ${state.message}'),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 64),
              ),
            );
          }
        },
        child: Container(
          color: Theme.of(context).colorScheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlocBuilder<WindowBloc, WindowManagerState>(
                builder: (context, windowState) {
                  final isFocused = windowState.isTopmost(widget.windowId);
                  return Container(
                    color: isFocused ? Colors.deepPurple : Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.create_new_folder,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'New Folder',
                          onPressed: _createFolder,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.upload_file,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Upload File',
                          onPressed: _uploadFile,
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<List<FileItem>>(
                  stream: getIt<FileSystemRepository>().watchFolder(
                    _currentFolder.id,
                  ),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const [];
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'This folder is empty',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      );
                    }
                    return GestureDetector(
                      onSecondaryTapDown: (details) async {
                        final clipboard = context.read<FileClipboardCubit>();
                        final selection = await showMenu<String>(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                          ),
                          items: [
                            const PopupMenuItem(
                              value: 'new_folder',
                              child: Text('New Folder'),
                            ),
                            const PopupMenuItem(
                              value: 'upload',
                              child: Text('Upload File'),
                            ),
                            if (!clipboard.state.isEmpty)
                              const PopupMenuItem(
                                value: 'paste',
                                child: Text('Paste'),
                              ),
                          ],
                        );
                        if (selection == 'new_folder') _createFolder();
                        if (selection == 'upload') _uploadFile();
                        if (selection == 'paste') {
                          await pasteClipboardItem(
                            context: context,
                            clipboard: clipboard,
                            destinationFolderId: _currentFolder.id,
                          );
                        }
                      },
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final item in items)
                              DesktopIcon(
                                item: item,
                                iconColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                                isSelected: false,
                                onFolderDoubleTap: item.isFolder
                                    ? () => _openSubfolder(item)
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
