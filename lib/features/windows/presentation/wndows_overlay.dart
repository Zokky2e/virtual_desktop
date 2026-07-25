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
        final visible = state.windows.where((w) => !w.isMinimized).toList()
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

        if (visible.isEmpty) return const SizedBox.shrink();

        final topZ = visible.last.zIndex;

        return Stack(
          children: [
            for (final window in visible) ...[
              DraggableWindow(window: window, isFocused: window.zIndex == topZ),
              ResizeHandle(window: window),
            ],
          ],
        );
      },
    );
  }
}
