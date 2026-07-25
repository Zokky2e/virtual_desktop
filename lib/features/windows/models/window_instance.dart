import 'package:flutter/widgets.dart';
import 'package:equatable/equatable.dart';

class WindowInstance extends Equatable {
  const WindowInstance({
    required this.id,
    required this.title,
    required this.position,
    required this.size,
    required this.zIndex,
    required this.contentBuilder,
    this.isMinimized = false,
  });

  final String id;
  final String title;
  final Offset position;
  final Size size;
  final int zIndex;
  final bool isMinimized;

  /// Arbitrary window body — Phase 10's PreviewBloc plugs in here later,
  /// but for now it's whatever widget the caller wants rendered.
  final WidgetBuilder contentBuilder;

  WindowInstance copyWith({
    String? title,
    Offset? position,
    Size? size,
    int? zIndex,
    bool? isMinimized,
  }) {
    return WindowInstance(
      id: id,
      title: title ?? this.title,
      position: position ?? this.position,
      size: size ?? this.size,
      zIndex: zIndex ?? this.zIndex,
      isMinimized: isMinimized ?? this.isMinimized,
      contentBuilder: contentBuilder,
    );
  }

  @override
  List<Object?> get props => [id, title, position, size, zIndex, isMinimized];
  // contentBuilder is deliberately excluded — it's a function reference,
  // Equatable would only ever compare it by identity anyway.
}
