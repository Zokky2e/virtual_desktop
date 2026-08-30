// Conditionally selects the video preview implementation:
//  - Web build       -> video_viewer_web.dart      (video_player)
//  - Windows/Linux/macOS/mobile -> video_viewer_desktop.dart (flutter_vlc_player)
//
// See Windows-Desktop-Video-Player-VLC-Plan.md for why libVLC was chosen
// for desktop and what to swap to if CPU usage becomes a problem — that
// swap only ever touches video_viewer_desktop.dart, nothing upstream.
export 'video_viewer_stub.dart'
    if (dart.library.js_interop) 'video_viewer_web.dart'
    if (dart.library.io) 'video_viewer_desktop.dart';
