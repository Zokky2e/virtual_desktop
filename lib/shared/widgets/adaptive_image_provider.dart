// lib/shared/widgets/adaptive_image_provider.dart
export 'adaptive_image_provider_stub.dart'
    if (dart.library.io) 'adaptive_image_provider_io.dart'
    if (dart.library.js_interop) 'adaptive_image_provider_web.dart';
