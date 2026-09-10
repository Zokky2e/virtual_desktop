import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants.dart';
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
    // sharedOwnerId, not the 'shared' get_it instance name this used to
    // read: the two spell the same string today, but only one of them is
    // a value the server persists in owner_id.
    final uid = event.isShared
        ? sharedOwnerId
        : _authRepository.currentUser?.uid;
    if (uid == null) {
      emit(const UploadFailure('Not signed in.'));
      return;
    }

    emit(const UploadInProgress(0));

    // No storage key is built here any more: the key layout is the
    // storage provider's business, and the one this bloc used to invent
    // was ignored by the active provider except as a filename fallback.
    // Which tree this lands in is already settled by which registration
    // was injected, so no isShared flag either.
    final uploadResult = await _storageService.uploadFile(
      bytes: event.bytes,
      fileName: event.fileName,
      mimeType: event.mimeType,
      ownerId: uid,
      parentFolderId: event.parentFolderId,
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
