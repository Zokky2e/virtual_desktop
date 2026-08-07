import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../../core/services/storage_service.dart';
import 'upload_event.dart';
import 'upload_state.dart';

class UploadBloc extends Bloc<UploadEvent, UploadState> {
  UploadBloc({
    required StorageService storageService,
    required FileSystemRepository fileSystemRepository,
    required AuthRepository authRepository,
  }) : _storageService = storageService,
       _fileSystemRepository = fileSystemRepository,
       _authRepository = authRepository,
       super(const UploadIdle()) {
    on<UploadFileRequested>(_onUploadRequested);
  }

  final StorageService _storageService;
  final FileSystemRepository _fileSystemRepository;
  final AuthRepository _authRepository;

  Future<void> _onUploadRequested(
    UploadFileRequested event,
    Emitter<UploadState> emit,
  ) async {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) {
      emit(const UploadFailure('Not signed in.'));
      return;
    }

    emit(const UploadInProgress(0));

    final storageKey =
        'users/$uid/${DateTime.now().millisecondsSinceEpoch}_${event.fileName}';

    final uploadResult = await _storageService.uploadFile(
      bytes: event.bytes,
      path: storageKey,
      mimeType: event.mimeType,
      parentFolderId: event.parentFolderId,
      fileName: event.fileName,
      onProgress: (progress) => emit(UploadInProgress(progress)),
    );

    await uploadResult.match(
      (failure) async => emit(UploadFailure(failure.message)),
      (path) async {
        final createResult = await _fileSystemRepository.createFile(
          name: event.fileName,
          parentFolderId: event.parentFolderId,
          ownerId: uid,
          type: _typeFromMime(event.mimeType),
          storageKey: path,
          size: event.bytes.length,
        );
        createResult.match(
          (failure) => emit(UploadFailure(failure.message)),
          (item) => emit(UploadSuccess(item)),
        );
      },
    );
  }

  FileItemType _typeFromMime(String mimeType) {
    if (mimeType.startsWith('image/')) return FileItemType.image;
    if (mimeType.startsWith('video/')) return FileItemType.video;
    if (mimeType.startsWith('audio/')) return FileItemType.audio;
    if (mimeType == 'application/pdf') return FileItemType.pdf;
    if (mimeType == 'application/json') return FileItemType.json;
    if (mimeType == 'text/markdown') return FileItemType.markdown;
    if (mimeType.startsWith('text/')) return FileItemType.text;
    if (mimeType == 'application/x-subrip' || mimeType == 'text/vtt') {
      return FileItemType.subtitle;
    }
    return FileItemType.other;
  }
}
