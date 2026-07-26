import 'package:equatable/equatable.dart';
import '../../../core/models/file_item.dart';

class DesktopState extends Equatable {
  const DesktopState({
    this.currentFolderId,
    this.items = const [],
    this.selectedItemIds = const {},
    this.wallpaperAssetPath = 'assets/wallpapers/default.jpg',
    this.isLoading = true,
  });

  final String? currentFolderId;
  final List<FileItem> items;
  final Set<String> selectedItemIds;
  final String wallpaperAssetPath;
  final bool isLoading;

  DesktopState copyWith({
    String? currentFolderId,
    List<FileItem>? items,
    Set<String>? selectedItemIds,
    String? wallpaperAssetPath,
    bool? isLoading,
  }) {
    return DesktopState(
      currentFolderId: currentFolderId ?? this.currentFolderId,
      items: items ?? this.items,
      selectedItemIds: selectedItemIds ?? this.selectedItemIds,
      wallpaperAssetPath: wallpaperAssetPath ?? this.wallpaperAssetPath,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
    currentFolderId,
    items,
    selectedItemIds,
    wallpaperAssetPath,
    isLoading,
  ];
}
