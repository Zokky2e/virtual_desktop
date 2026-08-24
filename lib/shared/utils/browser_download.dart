export 'browser_download_stub.dart'
    if (dart.library.html) 'browser_download_web.dart'
    if (dart.library.io) 'browser_download_desktop.dart';
