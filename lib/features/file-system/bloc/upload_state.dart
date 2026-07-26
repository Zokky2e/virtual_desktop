import 'package:equatable/equatable.dart';
import '../../../core/models/file_item.dart';

abstract class UploadState extends Equatable {
  const UploadState();
  @override
  List<Object?> get props => [];
}

class UploadIdle extends UploadState {
  const UploadIdle();
}

class UploadInProgress extends UploadState {
  const UploadInProgress(this.progress);
  final double progress;
  @override
  List<Object?> get props => [progress];
}

class UploadSuccess extends UploadState {
  const UploadSuccess(this.item);
  final FileItem item;
  @override
  List<Object?> get props => [item];
}

class UploadFailure extends UploadState {
  const UploadFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
