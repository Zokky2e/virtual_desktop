import 'package:equatable/equatable.dart';
import '../models/window_instance.dart';

class WindowManagerState extends Equatable {
  const WindowManagerState({this.windows = const []});

  final List<WindowInstance> windows;

  WindowManagerState copyWith({List<WindowInstance>? windows}) {
    return WindowManagerState(windows: windows ?? this.windows);
  }

  bool isTopmost(String windowId) {
    final visible = windows.where((w) => !w.isMinimized);
    if (visible.isEmpty) return false;
    final topZ = visible.map((w) => w.zIndex).reduce((a, b) => a > b ? a : b);
    final window = windows.where((w) => w.id == windowId);
    if (window.isEmpty) return false;
    return window.first.zIndex == topZ;
  }

  @override
  List<Object?> get props => [windows];
}
