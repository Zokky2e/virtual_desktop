import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/window_bloc.dart';
import '../bloc/window_event.dart';
import '../models/window_instance.dart';

class ResizeHandle extends StatefulWidget {
  const ResizeHandle({super.key, required this.window});

  final WindowInstance window;

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  Offset? _dragStartGlobalPosition;
  Size? _sizeAtDragStart;

  @override
  Widget build(BuildContext context) {
    final window = widget.window;
    return Positioned(
      left: window.position.dx + window.size.width - 16,
      top: window.position.dy + window.size.height - 16,
      child: GestureDetector(
        onPanStart: (details) {
          _dragStartGlobalPosition = details.globalPosition;
          _sizeAtDragStart = window.size;
        },
        onPanUpdate: (details) {
          if (_dragStartGlobalPosition == null || _sizeAtDragStart == null)
            return;
          final totalDelta = details.globalPosition - _dragStartGlobalPosition!;
          final newSize = Size(
            _sizeAtDragStart!.width + totalDelta.dx,
            _sizeAtDragStart!.height + totalDelta.dy,
          );
          context.read<WindowBloc>().add(WindowResized(window.id, newSize));
        },
        onPanEnd: (_) {
          _dragStartGlobalPosition = null;
          _sizeAtDragStart = null;
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
