// lib/shared/widgets/adaptive_image_provider_io.dart
import 'dart:io';
import 'package:flutter/widgets.dart';

/// Native builds (desktop today, mobile later). API-served wallpapers are
/// still http(s) URLs; only local wallpaper storage keys are file paths.
ImageProvider adaptiveImageProvider(String pathOrUrl) {
  final isHttp =
      pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://');
  return isHttp ? NetworkImage(pathOrUrl) : FileImage(File(pathOrUrl));
}
