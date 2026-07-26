import 'package:equatable/equatable.dart';

abstract class PreviewContent extends Equatable {
  const PreviewContent();
  @override
  List<Object?> get props => [];
}

class UrlPreviewContent extends PreviewContent {
  const UrlPreviewContent(this.url);
  final String url;
  @override
  List<Object?> get props => [url];
}

class TextPreviewContent extends PreviewContent {
  const TextPreviewContent(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}
