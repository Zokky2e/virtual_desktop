import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/file_item.dart';
import '../../../core/services/storage_service.dart';
import '../models/preview_content.dart';
import 'preview_event.dart';
import 'preview_state.dart';

class PreviewBloc extends Bloc<PreviewEvent, PreviewState> {
  PreviewBloc({required StorageService storageService})
    : _storageService = storageService,
      super(const PreviewLoading()) {
    on<PreviewRequested>(_onRequested);
  }

  final StorageService _storageService;

  static const _urlBasedTypes = {
    FileItemType.image,
    FileItemType.video,
    FileItemType.audio,
    FileItemType.pdf,
  };

  static const _textBasedTypes = {
    FileItemType.text,
    FileItemType.json,
    FileItemType.markdown,
  };

  Future<void> _onRequested(
    PreviewRequested event,
    Emitter<PreviewState> emit,
  ) async {
    emit(const PreviewLoading());

    final storageKey = event.item.storageKey;
    if (storageKey == null) {
      emit(const PreviewFailure('This item has no file content to preview.'));
      return;
    }

    if (_urlBasedTypes.contains(event.item.type)) {
      final result = await _storageService.getDownloadUrl(storageKey);
      result.match(
        (failure) => emit(PreviewFailure(failure.message)),
        (url) => emit(PreviewReady(UrlPreviewContent(url))),
      );
      return;
    }

    if (_textBasedTypes.contains(event.item.type)) {
      final result = await _storageService.downloadFile(storageKey);
      result.match((failure) => emit(PreviewFailure(failure.message)), (bytes) {
        try {
          emit(PreviewReady(TextPreviewContent(utf8.decode(bytes))));
        } catch (_) {
          emit(const PreviewFailure('Could not decode file as text.'));
        }
      });
      return;
    }

    emit(
      const PreviewFailure('Preview isn\'t supported for this file type yet.'),
    );
  }
}
