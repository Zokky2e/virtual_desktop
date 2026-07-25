import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/repositories/file_system_repository.dart';
import 'desktop_event.dart';
import 'desktop_state.dart';

class DesktopBloc extends Bloc<DesktopEvent, DesktopState> {
  DesktopBloc({required FileSystemRepository fileSystemRepository})
    : _fileSystemRepository = fileSystemRepository,
      super(const DesktopState()) {
    on<DesktopFolderWatchRequested>(_onFolderWatchRequested);
    on<DesktopItemsUpdated>(_onItemsUpdated);
    on<DesktopIconSelected>(_onIconSelected);
    on<DesktopSelectionCleared>(_onSelectionCleared);
    on<DesktopWallpaperChanged>(_onWallpaperChanged);
  }

  final FileSystemRepository _fileSystemRepository;
  StreamSubscription? _folderSubscription;

  Future<void> _onFolderWatchRequested(
    DesktopFolderWatchRequested event,
    Emitter<DesktopState> emit,
  ) async {
    emit(state.copyWith(currentFolderId: event.folderId, isLoading: true));
    await _folderSubscription?.cancel();
    _folderSubscription = _fileSystemRepository
        .watchFolder(event.folderId)
        .listen((items) => add(DesktopItemsUpdated(items)));
  }

  void _onItemsUpdated(DesktopItemsUpdated event, Emitter<DesktopState> emit) {
    emit(state.copyWith(items: event.items, isLoading: false));
  }

  void _onIconSelected(DesktopIconSelected event, Emitter<DesktopState> emit) {
    final updated = event.addToSelection
        ? {...state.selectedItemIds, event.itemId}
        : {event.itemId};
    emit(state.copyWith(selectedItemIds: updated));
  }

  void _onSelectionCleared(
    DesktopSelectionCleared event,
    Emitter<DesktopState> emit,
  ) {
    emit(state.copyWith(selectedItemIds: {}));
  }

  void _onWallpaperChanged(
    DesktopWallpaperChanged event,
    Emitter<DesktopState> emit,
  ) {
    emit(state.copyWith(wallpaperAssetPath: event.wallpaperAssetPath));
  }

  @override
  Future<void> close() {
    _folderSubscription?.cancel();
    return super.close();
  }
}
