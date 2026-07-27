import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/core/models/app_settings.dart';
import 'package:virtual_desktop/core/repositories/auth_repository.dart';
import 'package:virtual_desktop/core/repositories/file_system_repository.dart';
import 'package:virtual_desktop/core/services/storage_service.dart';
import 'package:virtual_desktop/features/file-system/bloc/upload_bloc.dart';
import 'package:virtual_desktop/features/file-system/bloc/upload_event.dart';
import 'package:virtual_desktop/features/file-system/bloc/upload_state.dart';
import 'package:virtual_desktop/features/file-system/clipboard/file_clipboard_cubit.dart';
import 'package:virtual_desktop/features/file-system/presentation/recycle_bin_window_content.dart';
import 'package:virtual_desktop/features/file-system/presentation/search_window_content.dart';
import 'package:virtual_desktop/features/settings/bloc/settings_bloc.dart';
import 'package:virtual_desktop/features/settings/bloc/settings_state.dart';
import 'package:virtual_desktop/features/settings/presentation/settings_window_content.dart';
import 'package:virtual_desktop/features/windows/bloc/window_event.dart';
import 'package:virtual_desktop/features/windows/presentation/taskbar.dart';
import 'package:virtual_desktop/features/windows/presentation/windows_overlay.dart';
import 'package:virtual_desktop/shared/utils/mime_utils.dart';
import 'package:virtual_desktop/shared/widgets/file_item_actions.dart';
import '../../../core/di/injector.dart';
import '../../authentication/bloc/auth_bloc.dart';
import '../../authentication/bloc/auth_event.dart';
import '../../windows/bloc/window_bloc.dart';
import '../bloc/desktop_bloc.dart';
import '../bloc/desktop_event.dart';
import '../bloc/desktop_state.dart';
import 'desktop_icon.dart';

class DesktopPage extends StatelessWidget {
  const DesktopPage({super.key});

  void addNewFolder(BuildContext context) {
    final uid = getIt<AuthRepository>().currentUser!.uid;
    getIt<FileSystemRepository>().createFolder(
      name: 'New Folder',
      parentFolderId: null,
      ownerId: uid,
    );
  }

  Future<void> uploadFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file?.bytes == null) return;
    if (context.mounted) {
      context.read<UploadBloc>().add(
        UploadFileRequested(
          bytes: file!.bytes!,
          fileName: file.name,
          mimeType: mimeTypeForFileName(file.name),
          parentFolderId:
              null, // root only, per your folder-scoping decision — nested uploads land here once folder-browsing windows exist
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              DesktopBloc(fileSystemRepository: getIt<FileSystemRepository>())
                ..add(const DesktopFolderWatchRequested(null)),
        ),
        BlocProvider(create: (_) => WindowBloc()),
        BlocProvider(
          create: (_) => UploadBloc(
            storageService: getIt<StorageService>(),
            fileSystemRepository: getIt<FileSystemRepository>(),
            authRepository: getIt<AuthRepository>(),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: BlocListener<UploadBloc, UploadState>(
              listener: (context, state) => {
                if (state is UploadFailure)
                  {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Upload failed: ${state.message}'),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 64,
                        ),
                      ),
                    ),
                  }
                else if (state is UploadSuccess)
                  {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Uploaded ${state.item.name}'),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 64,
                        ),
                      ),
                    ),
                  },
              },
              child: BlocBuilder<DesktopBloc, DesktopState>(
                builder: (context, state) {
                  return GestureDetector(
                    onTap: () => context.read<DesktopBloc>().add(
                      const DesktopSelectionCleared(),
                    ),
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
                      if (selection == 'new_folder') addNewFolder(context);
                      if (selection == 'upload') uploadFile(context);
                      if (selection == 'paste') {
                        await pasteClipboardItem(
                          context: context,
                          clipboard: clipboard,
                          destinationFolderId: null,
                        );
                      }
                    },
                    child: Stack(
                      children: [
                        BlocBuilder<SettingsBloc, SettingsState>(
                          builder: (context, settingsState) {
                            final settings = settingsState is SettingsLoaded
                                ? settingsState.settings
                                : null;
                            final backgroundDecoration =
                                settings?.wallpaperType ==
                                        WallpaperType.image &&
                                    settings?.wallpaperImageUrl != null
                                ? BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(
                                        settings!.wallpaperImageUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : BoxDecoration(
                                    color:
                                        settings?.wallpaperColor ??
                                        const Color(0xFF1E2A38),
                                  );

                            return Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: backgroundDecoration,
                              padding: const EdgeInsets.only(bottom: 48),
                              child: state.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: [
                                          for (final item in state.items)
                                            DesktopIcon(
                                              item: item,
                                              isSelected: state.selectedItemIds
                                                  .contains(item.id),
                                            ),
                                        ],
                                      ),
                                    ),
                            );
                          },
                        ),
                        const WindowsOverlay(),
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Taskbar(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
