import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/core/models/file_item.dart';
import 'package:virtual_desktop/core/repositories/auth_repository.dart';
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
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Desktop'),
          actions: [
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              onPressed: () => addNewFolder(context),
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
