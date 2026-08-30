export 'pdf_viewer_stub.dart'
    if (dart.library.js_interop) 'pdf_viewer_web.dart'
    if (dart.library.io) 'pdf_viewer_desktop.dart';
