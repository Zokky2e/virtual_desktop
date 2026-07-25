import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/core/models/file_item.dart';
import 'package:virtual_desktop/core/repositories/file_system_repository.dart';
import 'package:virtual_desktop/features/windows/presentation/wndows_overlay.dart';
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

  void addTemporaryIcons() {
    // TEMPORARY — remove once Phase 8 wires real folder creation UI.
    getIt<FileSystemRepository>().createFolder(
      name: 'Test Folder',
      parentFolderId: null,
      ownerId: 'fake-uid',
    );
    getIt<FileSystemRepository>().createFile(
      name: 'Test File',
      parentFolderId: null,
      ownerId: 'fake-uid',
      type: FileItemType.image,
      storageKey: "fake-storage-key",
      size: 32,
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
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Desktop'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => addTemporaryIcons(),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  context.read<AuthBloc>().add(const AuthSignOutRequested()),
            ),
          ],
        ),
        body: BlocBuilder<DesktopBloc, DesktopState>(
          builder: (context, state) {
            return GestureDetector(
              onTap: () => context.read<DesktopBloc>().add(
                const DesktopSelectionCleared(),
              ),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: const Color(0xFF1E2A38),
                    child: state.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final item in state.items)
                                DesktopIcon(
                                  item: item,
                                  isSelected: state.selectedItemIds.contains(
                                    item.id,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const WindowsOverlay(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
