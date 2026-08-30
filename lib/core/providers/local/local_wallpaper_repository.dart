// lib/core/providers/local/local_wallpaper_repository.dart
//
// LocalWallpaperRepository is desktop-only — it stores its index on disk via
// `dart:io`. Exporting it conditionally keeps that import out of the web
// compilation unit entirely, so the compiler (not a runtime `kIsWeb` check in
// injector.dart) is what guarantees web never reaches it. Same pattern as
// shared/utils/browser_download.dart.
export 'local_wallpaper_repository_stub.dart'
    if (dart.library.io) 'local_wallpaper_repository_io.dart';
