import 'dart:typed_data';
import 'package:equatable/equatable.dart';

abstract class DownloadState extends Equatable {
  const DownloadState();
  @override
  List<Object?> get props => [];
}

class DownloadIdle extends DownloadState {
  const DownloadIdle();
}

class DownloadInProgress extends DownloadState {
  const DownloadInProgress();
}

class DownloadSuccess extends DownloadState {
  const DownloadSuccess(this.bytes, this.fileName);
  final Uint8List bytes;
  final String fileName;
  @override
  List<Object?> get props => [bytes.length, fileName];
}

class DownloadFailure extends DownloadState {
  const DownloadFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
