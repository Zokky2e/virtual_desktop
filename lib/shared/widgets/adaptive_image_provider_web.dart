// lib/shared/widgets/adaptive_image_provider_web.dart
import 'package:flutter/widgets.dart';

/// Web has no local filesystem to fall back to — always a network image.
ImageProvider adaptiveImageProvider(String pathOrUrl) =>
    NetworkImage(pathOrUrl);
