import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import '../error/failure.dart';

abstract class StorageService {
  Future<Either<Failure, String>> uploadFile({
    required Uint8List bytes,
    required String path,
    required String mimeType,
    void Function(double progress)? onProgress,
  });

  Future<Either<Failure, Unit>> deleteFile(String path);

  Future<Either<Failure, Uint8List>> downloadFile(String path);

  Future<Either<Failure, String>> getDownloadUrl(String path);
}
