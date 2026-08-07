import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Thin wrapper around the browser's Fullscreen API
/// (https://developer.mozilla.org/en-US/docs/Web/API/Fullscreen_API).
/// This is the optional "use the browser Fullscreen API on Flutter Web"
/// enhancement — the dedicated fullscreen *page* works regardless, so
/// failures here are swallowed rather than surfaced (some environments,
/// e.g. an iframe without `allowfullscreen`, reject the request).
Future<void> requestBrowserFullscreen() async {
  try {
    await web.document.documentElement?.requestFullscreen().toDart;
  } catch (_) {
    // Not fatal — the in-app fullscreen page still fills the viewport.
  }
}

Future<void> exitBrowserFullscreen() async {
  try {
    if (web.document.fullscreenElement != null) {
      await web.document.exitFullscreen().toDart;
    }
  } catch (_) {}
}
