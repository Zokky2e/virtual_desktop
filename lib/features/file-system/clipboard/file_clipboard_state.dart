import 'package:equatable/equatable.dart';
import '../../../core/models/file_item.dart';

enum ClipboardMode { copy, cut }

class FileClipboardState extends Equatable {
  const FileClipboardState({this.item, this.mode});

  final FileItem? item;
  final ClipboardMode? mode;

  bool get isEmpty => item == null;

  FileClipboardState copyWith({FileItem? item, ClipboardMode? mode}) {
    return FileClipboardState(item: item, mode: mode);
  }

  static const empty = FileClipboardState();

  @override
  List<Object?> get props => [item, mode];
}
