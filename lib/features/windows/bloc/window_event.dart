import 'package:flutter/widgets.dart';
import 'package:equatable/equatable.dart';

abstract class WindowEvent extends Equatable {
  const WindowEvent();
  @override
  List<Object?> get props => [];
}

/// Opens a new window, or focuses an existing one if [id] is already open —
/// this is what lets double-clicking the same desktop icon twice just
/// refocus the window instead of spawning duplicates.
class WindowOpened extends WindowEvent {
  const WindowOpened({
    required this.id,
    required this.title,
    required this.contentBuilder,
    this.initialPosition,
    this.initialSize,
  });

  final String id;
  final String title;
  final WidgetBuilder contentBuilder;
  final Offset? initialPosition;
  final Size? initialSize;

  @override
  List<Object?> get props => [id, title, initialPosition, initialSize];
}

class WindowClosed extends WindowEvent {
  const WindowClosed(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class WindowFocused extends WindowEvent {
  const WindowFocused(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class WindowMoved extends WindowEvent {
  const WindowMoved(this.id, this.delta);
  final String id;
  final Offset delta;
  @override
  List<Object?> get props => [id, delta];
}

class WindowResized extends WindowEvent {
  const WindowResized(this.id, this.newSize);
  final String id;
  final Size newSize;
  @override
  List<Object?> get props => [id, newSize];
}

class WindowMinimizeToggled extends WindowEvent {
  const WindowMinimizeToggled(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class WindowTitleChanged extends WindowEvent {
  const WindowTitleChanged(this.id, this.newTitle);
  final String id;
  final String newTitle;
  @override
  List<Object?> get props => [id, newTitle];
}

class WindowLeadingChanged extends WindowEvent {
  const WindowLeadingChanged(this.id, this.leadingBuilder);
  final String id;

  /// Pass null to remove the leading widget entirely.
  final WidgetBuilder? leadingBuilder;
  @override
  List<Object?> get props => [id];
}
