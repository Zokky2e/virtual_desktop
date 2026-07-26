import 'package:equatable/equatable.dart';
import '../../../core/models/file_item.dart';

abstract class DesktopEvent extends Equatable {
  const DesktopEvent();
  @override
  List<Object?> get props => [];
}

class DesktopFolderWatchRequested extends DesktopEvent {
  const DesktopFolderWatchRequested(this.folderId);
  final String? folderId;
  @override
  List<Object?> get props => [folderId];
}

class DesktopItemsUpdated extends DesktopEvent {
  const DesktopItemsUpdated(this.items);
  final List<FileItem> items;
  @override
  List<Object?> get props => [items];
}

class DesktopIconSelected extends DesktopEvent {
  const DesktopIconSelected(this.itemId, {this.addToSelection = false});
  final String itemId;
  final bool addToSelection;
  @override
  List<Object?> get props => [itemId, addToSelection];
}

class DesktopSelectionCleared extends DesktopEvent {
  const DesktopSelectionCleared();
}

class DesktopWallpaperChanged extends DesktopEvent {
  const DesktopWallpaperChanged(this.wallpaperAssetPath);
  final String wallpaperAssetPath;
  @override
  List<Object?> get props => [wallpaperAssetPath];
}
