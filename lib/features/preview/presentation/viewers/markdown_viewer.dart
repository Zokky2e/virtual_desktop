import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownPreviewViewer extends StatelessWidget {
  const MarkdownPreviewViewer({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: text,
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(color: Colors.white),
        h1: const TextStyle(color: Colors.white),
        h2: const TextStyle(color: Colors.white),
        code: const TextStyle(
          color: Colors.white,
          backgroundColor: Colors.black26,
        ),
      ),
    );
  }
}
