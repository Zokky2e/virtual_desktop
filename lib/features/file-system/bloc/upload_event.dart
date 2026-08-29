import 'dart:typed_data';
import 'package:equatable/equatable.dart';

abstract class UploadEvent extends Equatable {
  const UploadEvent();
  @override
  List<Object?> get props => [];
}

class UploadFileRequested extends UploadEvent {
  const UploadFileRequested({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.parentFolderId,
    this.isShared = false,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final String? parentFolderId;
  final bool isShared;

  @override
  List<Object?> get props => [
    fileName,
    mimeType,
    parentFolderId,
    bytes.length,
    isShared,
  ];
}
