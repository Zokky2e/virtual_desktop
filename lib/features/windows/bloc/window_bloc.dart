import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/window_instance.dart';
import 'window_event.dart';
import 'window_state.dart';

class WindowBloc extends Bloc<WindowEvent, WindowManagerState> {
  WindowBloc() : super(const WindowManagerState()) {
    on<WindowOpened>(_onOpened);
    on<WindowClosed>(_onClosed);
    on<WindowFocused>(_onFocused);
    on<WindowMovedTo>(_onMovedTo);
    on<WindowResized>(_onResized);
    on<WindowMinimizeToggled>(_onMinimizeToggled);
    on<WindowTitleChanged>(_onTitleChanged);
    on<WindowLeadingChanged>(_onLeadingChanged);
    on<WindowChromeChanged>(_onChromeChanged);
  }

  static const _defaultSize = Size(480, 360);
  static const _minSize = Size(240, 160);
  static const _cascadeOffset = 32.0;

  int get _nextZIndex => state.windows.isEmpty
      ? 1
      : state.windows.map((w) => w.zIndex).reduce((a, b) => a > b ? a : b) + 1;

  void _onOpened(WindowOpened event, Emitter<WindowManagerState> emit) {
    final existingIndex = state.windows.indexWhere((w) => w.id == event.id);
    if (existingIndex != -1) {
      // Already open — bring it to front and un-minimize instead of duplicating.
      final updated = [...state.windows];
      updated[existingIndex] = updated[existingIndex].copyWith(
        zIndex: _nextZIndex,
        isMinimized: false,
      );
      emit(state.copyWith(windows: updated));
      return;
    }

    final cascade = _cascadeOffset * (state.windows.length % 8);
    final newWindow = WindowInstance(
      id: event.id,
      title: event.title,
      position: event.initialPosition ?? Offset(60 + cascade, 60 + cascade),
      size: event.initialSize ?? _defaultSize,
      zIndex: _nextZIndex,
      contentBuilder: event.contentBuilder,
    );
    emit(state.copyWith(windows: [...state.windows, newWindow]));
  }

  void _onClosed(WindowClosed event, Emitter<WindowManagerState> emit) {
    emit(
      state.copyWith(
        windows: state.windows.where((w) => w.id != event.id).toList(),
      ),
    );
  }

  void _onFocused(WindowFocused event, Emitter<WindowManagerState> emit) {
    final index = state.windows.indexWhere((w) => w.id == event.id);
    if (index == -1) return;
    // Already frontmost — skip the state churn.
    if (state.windows[index].zIndex == _nextZIndex - 1 &&
        index == state.windows.length - 1) {
      return;
    }
    final updated = [...state.windows];
    updated[index] = updated[index].copyWith(zIndex: _nextZIndex);
    emit(state.copyWith(windows: updated));
  }

  void _onMovedTo(WindowMovedTo event, Emitter<WindowManagerState> emit) {
    final index = state.windows.indexWhere((w) => w.id == event.id);
    if (index == -1) return;
    final updated = [...state.windows];
    updated[index] = updated[index].copyWith(position: event.newPosition);
    emit(state.copyWith(windows: updated));
  }

  void _onResized(WindowResized event, Emitter<WindowManagerState> emit) {
    final index = state.windows.indexWhere((w) => w.id == event.id);
    if (index == -1) return;
    final clamped = Size(
      event.newSize.width < _minSize.width
          ? _minSize.width
          : event.newSize.width,
      event.newSize.height < _minSize.height
          ? _minSize.height
          : event.newSize.height,
    );
    final updated = [...state.windows];
    updated[index] = updated[index].copyWith(size: clamped);
    emit(state.copyWith(windows: updated));
  }

  void _onMinimizeToggled(
    WindowMinimizeToggled event,
    Emitter<WindowManagerState> emit,
  ) {
    final index = state.windows.indexWhere((w) => w.id == event.id);
    if (index == -1) return;
    final updated = [...state.windows];
    updated[index] = updated[index].copyWith(
      isMinimized: !updated[index].isMinimized,
    );
    emit(state.copyWith(windows: updated));
  }

  void _onTitleChanged(
    WindowTitleChanged event,
    Emitter<WindowManagerState> emit,
  ) {
    final index = state.windows.indexWhere((w) => w.id == event.id);
    if (index == -1) return;
    final updated = [...state.windows];
    updated[index] = updated[index].copyWith(title: event.newTitle);
    emit(state.copyWith(windows: updated));
  }

  void _onLeadingChanged(
    WindowLeadingChanged event,
    Emitter<WindowManagerState> emit,
  ) {
    final index = state.windows.indexWhere((w) => w.id == event.id);
    if (index == -1) return;
    final updated = [...state.windows];
    updated[index] = updated[index].copyWith(
      leadingBuilder: event.leadingBuilder,
      clearLeadingBuilder: event.leadingBuilder == null,
    );
    emit(state.copyWith(windows: updated));
  }

  void _onChromeChanged(
    WindowChromeChanged event,
    Emitter<WindowManagerState> emit,
  ) {
    final index = state.windows.indexWhere((w) => w.id == event.id);
    if (index == -1) return;
    final updated = [...state.windows];
    updated[index] = updated[index].copyWith(
      title: event.title,
      leadingBuilder: event.leadingBuilder,
      clearLeadingBuilder: event.leadingBuilder == null,
    );
    emit(state.copyWith(windows: updated));
  }
}
