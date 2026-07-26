import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/core/models/app_settings.dart';
import 'package:virtual_desktop/core/models/file_item.dart';
import 'package:virtual_desktop/core/repositories/auth_repository.dart';
import 'package:virtual_desktop/core/repositories/file_system_repository.dart';
import 'package:virtual_desktop/core/services/storage_service.dart';
import 'package:virtual_desktop/features/file-system/bloc/upload_bloc.dart';
import 'package:virtual_desktop/features/file-system/bloc/upload_event.dart';
import 'package:virtual_desktop/features/file-system/bloc/upload_state.dart';
import 'package:virtual_desktop/features/settings/bloc/settings_bloc.dart';
import 'package:virtual_desktop/features/settings/bloc/settings_state.dart';
import 'package:virtual_desktop/features/settings/presentation/settings_window_content.dart';
import 'package:virtual_desktop/features/windows/bloc/window_event.dart';
import 'package:virtual_desktop/features/windows/presentation/windows_overlay.dart';
import 'package:virtual_desktop/shared/utils/mime_utils.dart';
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
    // context.read<DesktopBloc>().add(
    //   // DesktopBloc doesn't have a "create" event yet — call the
    //   // repository directly for now. Wiring this through a proper
    //   // DesktopFolderCreateRequested event is a good Phase 12 cleanup
    //   // once context menus replace this button anyway.
    // );
    getIt<FileSystemRepository>().createFolder(
      name: 'New Folder',
      parentFolderId: null,
      ownerId: uid,
    );
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
            appBar: AppBar(
              title: const Text('Desktop'),
              actions: [
                IconButton(
                  tooltip: 'Create Folder',
                  icon: const Icon(Icons.create_new_folder),
                  onPressed: () => addNewFolder(context),
                ),
                IconButton(
                  tooltip: 'Upload File',
                  icon: const Icon(Icons.upload_file),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      withData: true,
                    );
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
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => context.read<WindowBloc>().add(
                    WindowOpened(
                      id: 'settings-window',
                      title: 'Settings',
                      contentBuilder: (context) => const SettingsWindowContent(
                        key: ValueKey('settings-content'),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => context.read<AuthBloc>().add(
                    const AuthSignOutRequested(),
                  ),
                ),
              ],
            ),
            body: BlocListener<UploadBloc, UploadState>(
              listener: (context, state) => {
                if (state is UploadFailure)
                  {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Upload failed: ${state.message}'),
                      ),
                    ),
                  }
                else if (state is UploadSuccess)
                  {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Uploaded ${state.item.name}')),
                    ),
                  },
              },
              child: BlocBuilder<DesktopBloc, DesktopState>(
                builder: (context, state) {
                  return GestureDetector(
                    onTap: () => context.read<DesktopBloc>().add(
                      const DesktopSelectionCleared(),
                    ),
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
                              child: state.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : Wrap(
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
                            );
                          },
                        ),
                        const WindowsOverlay(),
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
