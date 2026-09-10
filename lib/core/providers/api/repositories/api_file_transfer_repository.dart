import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../error/failure.dart';
import '../../../models/file_item.dart';
import '../../../repositories/file_transfer_repository.dart';
import '../client/transfers_api.dart';
import '../models/file_response_mapper.dart';

class ApiFileTransferRepository implements FileTransferRepository {
  ApiFileTransferRepository({required TransfersApi transfersApi})
    : _api = transfersApi;

  final TransfersApi _api;

  @override
  Future<Either<Failure, FileItem>> transfer({
    required String itemId,
    required bool fromShared,
    required bool toShared,
    required String? destinationParentFolderId,
    required FileTransferMode mode,
    String? name,
  }) async {
    try {
      final json = await _api.transfer(
        itemId: itemId,
        fromShared: fromShared,
        toShared: toShared,
        parentFolderId: destinationParentFolderId,
        move: mode == FileTransferMode.move,
        name: name,
      );
      return Right(fileItemFromApiJson(json));
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  String _describe(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail'] : null;
      return detail?.toString() ?? e.message ?? 'Network error';
    }
    return e.toString();
  }
}
