import 'package:equatable/equatable.dart';
import '../models/window_instance.dart';

class WindowManagerState extends Equatable {
  const WindowManagerState({this.windows = const []});

  final List<WindowInstance> windows;

  WindowManagerState copyWith({List<WindowInstance>? windows}) {
    return WindowManagerState(windows: windows ?? this.windows);
  }

  @override
  List<Object?> get props => [windows];
}
