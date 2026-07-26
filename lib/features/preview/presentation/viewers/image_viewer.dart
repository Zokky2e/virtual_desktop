import 'package:flutter/material.dart';

class ImageViewer extends StatelessWidget {
  const ImageViewer({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        child: Image.network(
          url,
          errorBuilder: (context, error, stackTrace) => const Text(
            'Failed to load image',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
