import 'package:equatable/equatable.dart';

abstract class DownloadEvent extends Equatable {
  const DownloadEvent();
  @override
  List<Object?> get props => [];
}

class DownloadFileRequested extends DownloadEvent {
  const DownloadFileRequested({
    required this.storageKey,
    required this.fileName,
  });
  final String storageKey;
  final String fileName;
  @override
  List<Object?> get props => [storageKey, fileName];
}
