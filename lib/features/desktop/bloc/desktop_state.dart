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

    /// null is a meaningful value for [currentFolderId] — it means "the
    /// tree root", the same convention DesktopFolderWatchRequested(null)
    /// uses. Passing `currentFolderId: null` can't express that on its
    /// own, because it's indistinguishable from omitting the argument, so
    /// navigating back to the root silently kept the old folder id. Set
    /// this flag to clear it instead.
    bool clearCurrentFolderId = false,
    List<FileItem>? items,
    Set<String>? selectedItemIds,
    String? wallpaperAssetPath,
    bool? isLoading,
  }) {
    return DesktopState(
      currentFolderId: clearCurrentFolderId
          ? null
          : (currentFolderId ?? this.currentFolderId),
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
