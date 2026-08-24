import 'package:flutter/material.dart';

class PdfViewer extends StatelessWidget {
  const PdfViewer({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'PDF preview is not supported on this platform.',
      style: TextStyle(color: Colors.white70),
    ),
  );
}
