import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injector.dart';
import '../../../core/models/file_item.dart';
import '../../../core/services/storage_service.dart';
import '../bloc/preview_bloc.dart';
import '../bloc/preview_event.dart';
import '../bloc/preview_state.dart';
import '../models/preview_content.dart';
import 'viewers/image_viewer.dart';
import 'viewers/video_viewer.dart';
import 'viewers/audio_viewer.dart';
import 'viewers/pdf_viewer.dart';
import 'viewers/text_viewer.dart';
import 'viewers/json_viewer.dart';
import 'viewers/markdown_viewer.dart';

class PreviewWindowContent extends StatelessWidget {
  const PreviewWindowContent({super.key, required this.item});
  final FileItem item;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PreviewBloc(storageService: getIt<StorageService>())
            ..add(PreviewRequested(item)),
      child: Container(
        color: const Color(0xFF181818),
        child: BlocBuilder<PreviewBloc, PreviewState>(
          builder: (context, state) {
            if (state is PreviewLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is PreviewFailure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    state.message,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final content = (state as PreviewReady).content;
            return _buildViewer(content);
          },
        ),
      ),
    );
  }

  Widget _buildViewer(PreviewContent content) {
    if (content is UrlPreviewContent) {
      switch (item.type) {
        case FileItemType.image:
          return ImageViewer(url: content.url);
        case FileItemType.video:
          return VideoViewer(url: content.url);
        case FileItemType.audio:
          return AudioViewer(url: content.url);
        case FileItemType.pdf:
          return PdfViewer(url: content.url);
        default:
          return const Center(
            child: Text(
              'Unsupported preview',
              style: TextStyle(color: Colors.white70),
            ),
          );
      }
    }

    if (content is TextPreviewContent) {
      switch (item.type) {
        case FileItemType.markdown:
          return MarkdownPreviewViewer(text: content.text);
        case FileItemType.json:
          return JsonViewer(rawText: content.text);
        case FileItemType.text:
          return TextViewer(text: content.text);
        default:
          return const Center(
            child: Text(
              'Unsupported preview',
              style: TextStyle(color: Colors.white70),
            ),
          );
      }
    }

    return const Center(
      child: Text(
        'Unsupported preview',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
