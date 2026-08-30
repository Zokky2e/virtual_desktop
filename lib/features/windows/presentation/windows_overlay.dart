import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/window_bloc.dart';
import '../bloc/window_state.dart';
import 'draggable_window.dart';
import 'resize_handle.dart';

class WindowsOverlay extends StatelessWidget {
  const WindowsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WindowBloc, WindowManagerState>(
      builder: (context, state) {
        // Minimized windows stay in the tree — DraggableWindow renders them
        // Offstage. Filtering them out here instead would unmount the content
        // subtree and dispose its State, losing a folder window's navigation
        // stack and tearing down a video's player controller on every
        // minimize/restore.
        final windows = [...state.windows]
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

        if (windows.isEmpty) return const SizedBox.shrink();

        return Stack(
          children: [
            for (final window in windows) ...[
              DraggableWindow(
                key: ValueKey('window-${window.id}'),
                window: window,
                isFocused: state.isTopmost(window.id),
              ),
              // The handle carries no state, so it can just go away.
              if (!window.isMinimized)
                ResizeHandle(
                  key: ValueKey('resize-${window.id}'),
                  window: window,
                ),
            ],
          ],
        );
      },
    );
  }
}
