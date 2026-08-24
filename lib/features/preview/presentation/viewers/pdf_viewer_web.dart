import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class PdfViewer extends StatelessWidget {
  const PdfViewer({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final viewId = 'pdf-viewer-${url.hashCode}';

    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      return web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    });

    return HtmlElementView(viewType: viewId);
  }
}
