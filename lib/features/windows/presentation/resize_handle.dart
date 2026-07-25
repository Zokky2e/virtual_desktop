import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/window_bloc.dart';
import '../bloc/window_event.dart';
import '../models/window_instance.dart';

class ResizeHandle extends StatelessWidget {
  const ResizeHandle({super.key, required this.window});

  final WindowInstance window;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: window.position.dx + window.size.width - 16,
      top: window.position.dy + window.size.height - 16,
      child: GestureDetector(
        onPanUpdate: (details) {
          final newSize = Size(
            window.size.width + details.delta.dx,
            window.size.height + details.delta.dy,
          );
          context.read<WindowBloc>().add(WindowResized(window.id, newSize));
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeDownRight,
          child: Container(
            width: 16,
            height: 16,
            color: Colors.transparent,
            child: const Icon(
              Icons.drag_handle,
              size: 12,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
