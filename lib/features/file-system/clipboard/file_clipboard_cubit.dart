import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/file_item.dart';
import 'file_clipboard_state.dart';

/// App-wide "clipboard" for cut/copy/paste — deliberately a Cubit, not a
/// Bloc with events, since this is pure state-holding with no async work
/// or side effects of its own. The actual file operations (move/duplicate)
/// happen in file_item_actions.dart, which reads/clears this Cubit.
class FileClipboardCubit extends Cubit<FileClipboardState> {
  FileClipboardCubit() : super(FileClipboardState.empty);

  void copy(FileItem item) =>
      emit(FileClipboardState(item: item, mode: ClipboardMode.copy));

  void cut(FileItem item) =>
      emit(FileClipboardState(item: item, mode: ClipboardMode.cut));

  void clear() => emit(FileClipboardState.empty);
}
