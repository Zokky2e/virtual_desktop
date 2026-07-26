import 'dart:convert';
import 'package:flutter/material.dart';

class JsonViewer extends StatelessWidget {
  const JsonViewer({super.key, required this.rawText});
  final String rawText;

  @override
  Widget build(BuildContext context) {
    String pretty;
    try {
      final decoded = jsonDecode(rawText);
      pretty = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      pretty = rawText; // fall back to raw text if it's not valid JSON
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        pretty,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
    );
  }
}
