import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_desktop/core/di/injector.dart';
import 'package:virtual_desktop/core/providers/api/client/folders_api.dart';
import 'package:virtual_desktop/core/repositories/file_system_repository.dart';
import 'package:virtual_desktop/core/services/storage_service.dart';
import 'package:virtual_desktop/features/file-system/presentation/recycle_bin_window_content.dart';
import 'package:virtual_desktop/features/file-system/presentation/search_window_content.dart';
import 'package:virtual_desktop/features/windows/presentation/folder_window_content.dart';
import '../../authentication/bloc/auth_bloc.dart';
import '../../authentication/bloc/auth_event.dart';
import '../../settings/presentation/settings_window_content.dart';
import '../bloc/window_bloc.dart';
import '../bloc/window_event.dart';
import '../bloc/window_state.dart';

class Taskbar extends StatelessWidget {
  const Taskbar({super.key});

  void _openSingleton(
    BuildContext context, {
    required String id,
    required String title,
    required WidgetBuilder contentBuilder,
  }) {
    context.read<WindowBloc>().add(
      WindowOpened(id: id, title: title, contentBuilder: contentBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _TaskbarIconButton(
            icon: Icons.search,
            tooltip: 'Search',
            onPressed: () => _openSingleton(
              context,
              id: 'search-window',
              title: 'Search',
              contentBuilder: (context) =>
                  const SearchWindowContent(key: ValueKey('search-content')),
            ),
          ),
          _TaskbarIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Recycle Bin',
            onPressed: () => _openSingleton(
              context,
              id: 'recycle-bin-window',
              title: 'Recycle Bin',
              contentBuilder: (context) => const RecycleBinWindowContent(
                key: ValueKey('recycle-bin-content'),
              ),
            ),
          ),
          _TaskbarIconButton(
            icon: Icons.folder_shared,
            tooltip: 'Shared',
            onPressed: () => _openSingleton(
              context,
              id: 'shared-folder-window',
              title: 'Shared',
              contentBuilder: (context) => FolderWindowContent(
                key: const ValueKey('shared-folder-content'),
                windowId: 'shared-folder-window',
                rootTitle: 'Shared',
                isShared: true,
                fileSystemRepository: getIt<FileSystemRepository>(
                  instanceName: sharedInstanceName,
                ),
                storageService: getIt<StorageService>(
                  instanceName: sharedInstanceName,
                ),
                onSync: () =>
                    getIt<FoldersApi>(instanceName: sharedInstanceName).sync(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const VerticalDivider(color: Colors.white24, width: 1),
          const SizedBox(width: 8),
          Expanded(
            child: BlocBuilder<WindowBloc, WindowManagerState>(
              builder: (context, state) {
                if (state.windows.isEmpty) return const SizedBox.shrink();
                return ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final window in state.windows)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: _TaskbarEntry(
                          title: window.title,
                          isFocused:
                              !window.isMinimized && state.isTopmost(window.id),
                          isMinimized: window.isMinimized,
                          onTap: () {
                            final bloc = context.read<WindowBloc>();
                            if (window.isMinimized) {
                              bloc.add(
                                WindowOpened(
                                  id: window.id,
                                  title: window.title,
                                  contentBuilder: window.contentBuilder,
                                ),
                              );
                            } else if (state.isTopmost(window.id)) {
                              bloc.add(WindowMinimizeToggled(window.id));
                            } else {
                              bloc.add(WindowFocused(window.id));
                            }
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          const VerticalDivider(color: Colors.white24, width: 1),
          const SizedBox(width: 8),
          _TaskbarIconButton(
            icon: Icons.settings,
            tooltip: 'Settings',
            onPressed: () => _openSingleton(
              context,
              id: 'settings-window',
              title: 'Settings',
              contentBuilder: (context) => const SettingsWindowContent(
                key: ValueKey('settings-content'),
              ),
            ),
          ),
          _TaskbarIconButton(
            icon: Icons.logout,
            tooltip: 'Log Out',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignOutRequested()),
          ),
        ],
      ),
    );
  }
}

class _TaskbarIconButton extends StatelessWidget {
  const _TaskbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class _TaskbarEntry extends StatelessWidget {
  const _TaskbarEntry({
    required this.title,
    required this.isFocused,
    required this.isMinimized,
    required this.onTap,
  });

  final String title;
  final bool isFocused;
  final bool isMinimized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isFocused ? Colors.deepPurple : Colors.white12,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMinimized ? Icons.crop_square : Icons.web_asset,
              size: 14,
              color: Colors.white70,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
