import 'package:equatable/equatable.dart';
import '../../../core/models/file_item.dart';

abstract class PreviewEvent extends Equatable {
  const PreviewEvent();
  @override
  List<Object?> get props => [];
}

class PreviewRequested extends PreviewEvent {
  const PreviewRequested(this.item);
  final FileItem item;
  @override
  List<Object?> get props => [item];
}
