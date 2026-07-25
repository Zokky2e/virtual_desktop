import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/file_item.dart';
import '../bloc/desktop_bloc.dart';
import '../bloc/desktop_event.dart';

class DesktopIcon extends StatelessWidget {
  const DesktopIcon({super.key, required this.item, required this.isSelected});

  final FileItem item;
  final bool isSelected;

  IconData get _iconData {
    switch (item.type) {
      case FileItemType.folder:
        return Icons.folder;
      case FileItemType.image:
        return Icons.image;
      case FileItemType.video:
        return Icons.movie;
      case FileItemType.audio:
        return Icons.audiotrack;
      case FileItemType.pdf:
        return Icons.picture_as_pdf;
      case FileItemType.text:
        return Icons.description;
      case FileItemType.json:
        return Icons.data_object;
      case FileItemType.markdown:
        return Icons.article;
      case FileItemType.other:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Stop the tap from bubbling to the desktop's clear-selection handler.
        context.read<DesktopBloc>().add(DesktopIconSelected(item.id));
      },
      // Double-click/tap to open — actual "open a window" behavior lands in
      // Phase 7 once WindowBloc exists. For now this is a no-op placeholder.
      onDoubleTap: () {},
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconData, size: 40, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
