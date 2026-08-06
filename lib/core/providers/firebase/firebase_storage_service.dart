import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart' as fb;
import 'package:fpdart/fpdart.dart';
import '../../error/failure.dart';
import '../../services/storage_service.dart';

class FirebaseStorageService implements StorageService {
  FirebaseStorageService({fb.FirebaseStorage? storage})
    : _storage = storage ?? fb.FirebaseStorage.instance;

  final fb.FirebaseStorage _storage;

  @override
  Future<Either<Failure, String>> uploadFile({
    required Uint8List bytes,
    required String path,
    required String mimeType,
    String? parentFolderId,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref(path);
      final task = ref.putData(
        bytes,
        fb.SettableMetadata(contentType: mimeType),
      );

      if (onProgress != null) {
        task.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0) {
            onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
          }
        });
      }

      await task;
      return Right(path);
    } on fb.FirebaseException catch (e) {
      return Left(StorageFailure(e.message ?? 'Upload failed.'));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteFile(String path) async {
    try {
      await _storage.ref(path).delete();
      return const Right(unit);
    } on fb.FirebaseException catch (e) {
      return Left(StorageFailure(e.message ?? 'Delete failed.'));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Uint8List>> downloadFile(String path) async {
    try {
      final data = await _storage.ref(path).getData();
      if (data == null) return Left(StorageFailure('File not found: $path'));
      return Right(data);
    } on fb.FirebaseException catch (e) {
      return Left(StorageFailure(e.message ?? 'Download failed.'));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getDownloadUrl(String path) async {
    try {
      final url = await _storage.ref(path).getDownloadURL();
      return Right(url);
    } on fb.FirebaseException catch (e) {
      return Left(StorageFailure(e.message ?? 'Could not get download URL.'));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
