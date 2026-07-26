import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/storage_service.dart';
import 'download_event.dart';
import 'download_state.dart';

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  DownloadBloc({required StorageService storageService})
    : _storageService = storageService,
      super(const DownloadIdle()) {
    on<DownloadFileRequested>(_onDownloadRequested);
  }

  final StorageService _storageService;

  Future<void> _onDownloadRequested(
    DownloadFileRequested event,
    Emitter<DownloadState> emit,
  ) async {
    emit(const DownloadInProgress());
    final result = await _storageService.downloadFile(event.storageKey);
    result.match(
      (failure) => emit(DownloadFailure(failure.message)),
      (bytes) => emit(DownloadSuccess(bytes, event.fileName)),
    );
  }
}
