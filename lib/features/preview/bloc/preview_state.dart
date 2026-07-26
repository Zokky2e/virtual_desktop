import 'package:equatable/equatable.dart';
import '../models/preview_content.dart';

abstract class PreviewState extends Equatable {
  const PreviewState();
  @override
  List<Object?> get props => [];
}

class PreviewLoading extends PreviewState {
  const PreviewLoading();
}

class PreviewReady extends PreviewState {
  const PreviewReady(this.content);
  final PreviewContent content;
  @override
  List<Object?> get props => [content];
}

class PreviewFailure extends PreviewState {
  const PreviewFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
