import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/core/models/file_item.dart';
import '../../../core/di/injector.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../authentication/bloc/auth_bloc.dart';
import '../../authentication/bloc/auth_event.dart';
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
    return BlocProvider(
      create: (_) =>
          DesktopBloc(fileSystemRepository: getIt<FileSystemRepository>())
            ..add(const DesktopFolderWatchRequested(null)),
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
              // Tapping empty desktop space clears selection.
              onTap: () => context.read<DesktopBloc>().add(
                const DesktopSelectionCleared(),
              ),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                // Placeholder wallpaper — swap for Image.asset once real
                // wallpaper assets exist (Phase 11 wires up SettingsBloc).
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
            );
          },
        ),
      ),
    );
  }
}
