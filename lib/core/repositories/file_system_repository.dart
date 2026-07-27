import 'package:fpdart/fpdart.dart';
import '../error/failure.dart';
import '../models/file_item.dart';

abstract class FileSystemRepository {
  /// One-time fetch of a folder's direct children.
  /// Pass null for the root folder.
  Future<Either<Failure, List<FileItem>>> getFolder(String? folderId);

  /// Live updates for a folder's children — this is what DesktopBloc/
  /// FileSystemBloc will subscribe to instead of polling getFolder.
  Stream<List<FileItem>> watchFolder(String? folderId);

  Future<Either<Failure, FileItem>> createFolder({
    required String name,
    required String? parentFolderId,
    required String ownerId,
  });

  Future<Either<Failure, FileItem>> createFile({
    required String name,
    required String? parentFolderId,
    required String ownerId,
    required FileItemType type,
    required String storageKey,
    required int size,
  });

  Future<Either<Failure, Unit>> rename(String itemId, String newName);

  Future<Either<Failure, Unit>> move(String itemId, String? newParentFolderId);

  Future<Either<Failure, Unit>> deleteFolder(String folderId);

  Future<Either<Failure, Unit>> deleteFile(String fileId);

  Stream<List<FileItem>> watchDeletedItems(String ownerId);

  Future<Either<Failure, Unit>> restoreItem(String itemId);

  Future<Either<Failure, Unit>> hardDeleteItem(String itemId);

  Future<Either<Failure, List<FileItem>>> searchItems(
    String ownerId,
    String query,
  );

  Future<Either<Failure, bool>> nameExistsInFolder({
    required String ownerId,
    required String? parentFolderId,
    required String name,
  });
}
