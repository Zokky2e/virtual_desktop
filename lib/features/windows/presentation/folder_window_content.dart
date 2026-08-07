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
    this.rootFolder,
    this.rootFolderId,
    this.rootTitle,
    this.isShared = false,
    this.fileSystemRepository,
    this.storageService,
    this.onSync,
  }) : assert(
         rootFolder != null || rootTitle != null,
         'Provide either rootFolder (a real personal subfolder) or '
         'rootTitle (a synthetic root, e.g. the Shared folder).',
       );

  /// The WindowBloc id this content belongs to — needed to dispatch
  /// title/leading updates as the user navigates deeper or back.
  final String windowId;

  /// The folder this window was originally opened for, when it's a real
  /// file-tree item (e.g. double-clicking a personal subfolder). Null for
  /// synthetic roots with no backing FileItem — see [rootFolderId].
  final FileItem? rootFolder;

  /// Explicit starting-folder id when there's no [rootFolder] to derive
  /// it from. Null means "tree root" — the same convention
  /// DesktopFolderWatchRequested(null) uses for the personal root. This
  /// is what the Shared window passes.
  final String? rootFolderId;

  /// Explicit title for a synthetic root (e.g. 'Shared'). Ignored when
  /// [rootFolder] is provided — its name is used instead.
  final String? rootTitle;

  /// Whether this window is browsing the shared tree
  /// (storage_root/users/shared/ on the server) instead of the caller's
  /// own tree. Only controls whether the Sync button is shown.
  final bool isShared;

  /// Repository/service every operation in this window uses. Defaults to
  /// the unnamed (personal) getIt registrations, so opening a personal
  /// subfolder (desktop_icon.dart) is unaffected. The Shared window
  /// passes the 'shared'-named instances instead.
  final FileSystemRepository? fileSystemRepository;
  final StorageService? storageService;

  /// Calls POST /desktop/shared/sync on the server. Only meaningful (and
  /// only shown) when [isShared] is true.
  final Future<void> Function()? onSync;

  @override
  State<FolderWindowContent> createState() => _FolderWindowContentState();
}

/// One level of the in-window back-stack. [id] is the real folder id to
/// pass to watchFolder/createFolder/etc — null represents the tree root
/// (personal root or the Shared root).
class _FolderStackEntry {
  const _FolderStackEntry({required this.id, required this.name});
  final String? id;
  final String name;
}

class _FolderWindowContentState extends State<FolderWindowContent> {
  late final List<_FolderStackEntry> _folderStack;
  bool _isSyncing = false;

  FileSystemRepository get _repo =>
      widget.fileSystemRepository ?? getIt<FileSystemRepository>();
  StorageService get _storage =>
      widget.storageService ?? getIt<StorageService>();

  @override
  void initState() {
    super.initState();
    _folderStack = [
      _FolderStackEntry(
        id: widget.rootFolder?.id ?? widget.rootFolderId,
        name: widget.rootFolder?.name ?? widget.rootTitle!,
      ),
    ];
  }

  _FolderStackEntry get _currentFolder => _folderStack.last;

  void _openSubfolder(FileItem folder) {
    setState(
      () =>
          _folderStack.add(_FolderStackEntry(id: folder.id, name: folder.name)),
    );
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
    await _repo.createFolder(
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

  Future<void> _sync() async {
    final onSync = widget.onSync;
    if (onSync == null || _isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await onSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synced with server'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(left: 16, right: 16, bottom: 64),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 64),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UploadBloc(
        storageService: _storage,
        fileSystemRepository: _repo,
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
                        if (widget.isShared)
                          IconButton(
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.sync,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                            tooltip: 'Sync from server',
                            onPressed: _isSyncing ? null : _sync,
                          ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<List<FileItem>>(
                  stream: _repo.watchFolder(_currentFolder.id),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const [];
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          widget.isShared
                              ? 'Nothing here yet — upload a file or hit Sync'
                              : 'This folder is empty',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      );
                    }
                    return DragTarget<FileItem>(
                      // Empty space inside this folder window — drop lands in this folder.
                      onAcceptWithDetails: (details) =>
                          _repo.move(details.data.id, _currentFolder.id),
                      builder: (context, candidateData, rejectedData) {
                        return GestureDetector(
                          onSecondaryTapDown: (details) async {
                            final clipboard = context
                                .read<FileClipboardCubit>();
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
                                fileSystemRepository: _repo,
                                storageService: _storage,
                                isSharedDestination: widget.isShared,
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
                                    fileSystemRepository: _repo,
                                    storageService: _storage,
                                    onFolderDoubleTap: item.isFolder
                                        ? () => _openSubfolder(item)
                                        : null,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
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
