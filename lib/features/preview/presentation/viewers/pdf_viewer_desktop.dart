import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Desktop PDF preview. There's no dart:ui_web iframe trick available
/// here, and embedding a full PDF renderer (e.g. syncfusion_flutter_pdfviewer)
/// is a bigger dependency than this pass needs — so this just hands the
/// streaming URL off to the OS's default PDF viewer. Swap in an embedded
/// renderer later without touching PreviewBloc or preview_window_content.dart.
class PdfViewer extends StatelessWidget {
  const PdfViewer({super.key, required this.url});
  final String url;

  Future<void> _open() =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          const Text(
            'PDF preview opens in your default viewer on desktop.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _open,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open PDF'),
          ),
        ],
      ),
    );
  }
}
