import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injector.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../windows/bloc/window_bloc.dart';
import '../../windows/bloc/window_event.dart';
import '../../desktop/presentation/desktop_icon.dart';

class FolderWindowContent extends StatefulWidget {
  const FolderWindowContent({
    super.key,
    required this.windowId,
    required this.rootFolder,
  });

  /// The WindowBloc id this content belongs to — needed to dispatch
  /// title/leading updates as the user navigates deeper or back.
  final String windowId;

  /// The folder this window was originally opened for.
  final FileItem rootFolder;

  @override
  State<FolderWindowContent> createState() => _FolderWindowContentState();
}

class _FolderWindowContentState extends State<FolderWindowContent> {
  // Stack of folders navigated into, root folder always at index 0.
  late final List<FileItem> _folderStack;

  @override
  void initState() {
    super.initState();
    _folderStack = [widget.rootFolder];
  }

  FileItem get _currentFolder => _folderStack.last;

  void _openSubfolder(FileItem folder) {
    setState(() => _folderStack.add(folder));
    _syncWindowChrome();
  }

  void _goBack() {
    if (_folderStack.length <= 1) return;
    setState(() => _folderStack.removeLast());
    _syncWindowChrome();
  }

  void _syncWindowChrome() {
    final windowBloc = context.read<WindowBloc>();
    windowBloc.add(WindowTitleChanged(widget.windowId, _currentFolder.name));
    windowBloc.add(
      WindowLeadingChanged(
        widget.windowId,
        _folderStack.length > 1
            ? (context) => IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: _goBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FileItem>>(
      stream: getIt<FileSystemRepository>().watchFolder(_currentFolder.id),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'This folder is empty',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return Container(
          color: const Color(0xFF25344A),
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final item in items)
                DesktopIcon(
                  item: item,
                  isSelected: false,
                  onFolderDoubleTap: item.isFolder
                      ? () => _openSubfolder(item)
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}
