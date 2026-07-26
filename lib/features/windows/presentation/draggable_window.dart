import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/window_bloc.dart';
import '../bloc/window_event.dart';
import '../models/window_instance.dart';

class DraggableWindow extends StatelessWidget {
  const DraggableWindow({
    super.key,
    required this.window,
    required this.isFocused,
  });

  final WindowInstance window;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: window.position.dx,
      top: window.position.dy,
      width: window.size.width,
      height: window.size.height,
      child: GestureDetector(
        // Any tap inside the window (not just the title bar) brings it to front.
        onTapDown: (_) =>
            context.read<WindowBloc>().add(WindowFocused(window.id)),
        child: Material(
          elevation: isFocused ? 12 : 4,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _TitleBar(window: window, isFocused: isFocused),
              Expanded(child: window.contentBuilder(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.window, required this.isFocused});

  final WindowInstance window;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) =>
          context.read<WindowBloc>().add(WindowMoved(window.id, details.delta)),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: isFocused ? Colors.deepPurple : Colors.grey.shade700,
        child: Row(
          children: [
            if (window.leadingBuilder != null) window.leadingBuilder!(context),
            Expanded(
              child: Text(
                window.title,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _TitleBarButton(
              icon: Icons.minimize,
              onPressed: () => context.read<WindowBloc>().add(
                WindowMinimizeToggled(window.id),
              ),
            ),
            _TitleBarButton(
              icon: Icons.close,
              onPressed: () =>
                  context.read<WindowBloc>().add(WindowClosed(window.id)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatelessWidget {
  const _TitleBarButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
