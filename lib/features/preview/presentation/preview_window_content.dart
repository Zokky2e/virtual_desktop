import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injector.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/file_system_repository.dart';
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
import 'viewers/subtitle_models.dart';
import 'viewers/subtitle_track_loader.dart';

class PreviewWindowContent extends StatelessWidget {
  const PreviewWindowContent({
    super.key,
    required this.item,
    this.storageService,
    this.fileSystemRepository,
  });
  final FileItem item;
  final StorageService? storageService;

  /// Needed only for video items — used to look up sibling subtitle
  /// files in the same folder. Defaults to the personal-tree instance;
  /// the Shared window passes the 'shared'-named one, same pattern as
  /// [storageService].
  final FileSystemRepository? fileSystemRepository;

  @override
  Widget build(BuildContext context) {
    final resolvedStorage = storageService ?? getIt<StorageService>();
    return BlocProvider(
      create: (_) =>
          PreviewBloc(storageService: resolvedStorage)
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
            return _buildViewer(content, resolvedStorage);
          },
        ),
      ),
    );
  }

  Widget _buildViewer(PreviewContent content, StorageService storage) {
    if (content is UrlPreviewContent) {
      switch (item.type) {
        case FileItemType.image:
          return ImageViewer(url: content.url);
        case FileItemType.video:
          return _VideoPreview(
            url: content.url,
            item: item,
            fileSystemRepository:
                fileSystemRepository ?? getIt<FileSystemRepository>(),
            storageService: storage,
          );
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
        case FileItemType.subtitle:
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

/// Resolves sibling subtitle tracks before the video controller is ever
/// created — one clean [VideoViewer] instantiation with the right tracks
/// from the start, rather than trying to hot-swap tracks into an
/// already-initialized [VideoPlaybackController] via widget rebuilds.
class _VideoPreview extends StatefulWidget {
  const _VideoPreview({
    required this.url,
    required this.item,
    required this.fileSystemRepository,
    required this.storageService,
  });

  final String url;
  final FileItem item;
  final FileSystemRepository fileSystemRepository;
  final StorageService storageService;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final Future<List<SubtitleTrack>> _subtitlesFuture;

  @override
  void initState() {
    super.initState();
    _subtitlesFuture = loadSiblingSubtitleTracks(
      video: widget.item,
      fileSystemRepository: widget.fileSystemRepository,
      storageService: widget.storageService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SubtitleTrack>>(
      future: _subtitlesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return VideoViewer(
          url: widget.url,
          fileName: widget.item.name,
          subtitleTracks: snapshot.data ?? const [],
        );
      },
    );
  }
}
