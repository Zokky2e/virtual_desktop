# Scan report

Run: 2026-08-30, branch `develop` (at `f36fd89`).

Passes: `flutter analyze`, `dart run tool/scan.dart`, `flutter-bug-hunter`,
`flutter-arch-auditor`. Duplicates merged; the deliberate scope cuts CLAUDE.md
documents (recursive folder copy, Firebase being web-only, VLC CPU cost) are
not counted as findings.

| | High | Medium | Low |
|---|---|---|---|
| Found | 8 | 19 | 18 |
| Fixed this pass | 0 | 13 | 2 |
| Open | 8 | 6 | 16 |

**Mediums were the requested scope and are done**, except six that change
product behaviour or need backend routes — those are listed under
"Medium — open" with what each one needs.

Verification after the fixes: `flutter analyze` reports the same 10
pre-existing infos and no new ones; `dart run tool/scan.dart` is down from 21
findings to 1 low; `flutter build web` and `flutter build windows` both
succeed.

---

## Standing baseline

`test/widget_test.dart` is still the stale `flutter create` counter test and
fails. Known failure, not a regression.

## Not my change

`lib/core/providers/firebase/firestore_wallpaper_repository.dart` lost its
`// ignore: avoid_print` + `print('saveWallpaper failed: $e')` pair during this
session. That edit is in the working tree but was not made as part of this
work — review it before committing. It does match the `hygiene/print` finding
the scanner reported, so it is probably fine to keep.

---

## High — open

Not in the requested scope, but several are user-visible data or correctness
problems. Ranked by consequence.

### H1. Copy/paste writes the duplicate to the tree root under a mangled name
`lib/shared/widgets/file_item_actions.dart:235`

`pasteClipboardItem` calls `storage.uploadFile(bytes:, path:, mimeType:)` with
no `parentFolderId` and no `fileName`. `ApiStorageService` derives the name
from `path.split('/').last` and sends `parentFolderId: null`; the following
`repo.createFile` only re-fetches the record the server already created, so
the computed `resolvedName` and `destinationFolderId` are both discarded.

Copy a file, open a subfolder, paste: nothing appears there, and a file named
`1712345678901_report.pdf` shows up at the root of the tree instead. The
`_resolveCopyName` de-duplication is thrown away too.

Fix: pass `parentFolderId: destinationFolderId`, `fileName: resolvedName` (and
`isShared:`) into `uploadFile`.

### H2. Uploading from a folder window uses the ancestor `UploadBloc`
`lib/features/windows/presentation/folder_window_content.dart:150`, `:185`

`_uploadFile()` reads `UploadBloc` off `State.context`, but the `BlocProvider`
holding the tree-aware bloc is created *below* that context at `:185`.
`context.read` only walks ancestors, so it resolves `DesktopPage`'s bloc —
wired to the unnamed personal registrations. The local provider/listener pair
is dead code.

Shared → Upload File therefore posts to `/desktop/upload?isShared=true`
instead of `/desktop/shared/upload`. The bytes land correctly but the metadata
fetch is scoped to `user.uid` while the record's owner is `shared` → 404, so
the user sees "Upload finished but metadata lookup failed" for a file that
uploaded fine. `files.py` also notifies only the uploader, where `shared.py`
uses `broadcast_all` — so no other user's Shared window live-updates.

Fix: wrap the body in a `Builder`, or hoist the `BlocProvider` above
`FolderWindowContent` in `contentBuilder`.

### H3. WebSocket is never re-established after sign-out/sign-in
`lib/core/providers/api/client/api_websocket_client.dart:26`,
`lib/core/providers/api/repositories/api_file_system_repository.dart:20`

`connect()` runs once from a lazy-singleton repository constructor and returns
early forever after (`_channel != null`). `dispose()` has no call site and
`get_it` is never reset. The backend binds the socket to the uid from the
handshake token.

Log out, log in as another account without restarting, create a folder: it is
created server-side but the desktop never refreshes — events still route to
the previous user's socket bucket. Uploads, deletes and renames are all
invisible until restart.

Fix: own the socket explicitly — connect on `Authenticated`, tear down on
`Unauthenticated` — instead of connecting from a repository constructor.

### H4. WebSocket reconnect stacks connections and cancels the wrong subscription
`lib/core/providers/api/client/api_websocket_client.dart:45`, `:25`

`_reconnectAfterDelay` is wired to both `onDone` and `onError`; a failing
socket fires both, scheduling two reconnects. `connect()`'s `_channel != null`
guard sits *before* `await _getIdToken()`, so both pass it and both create a
channel — the second overwrites `_channel`/`_sub`, orphaning the first
listener, which keeps pushing into the shared event controller. The same
method also cancels whatever `_sub` currently is, which may belong to a
healthy socket, and never closes the old sink.

After any server restart or network blip, every `file_created`/`file_deleted`
is delivered N times and triggers N folder refetches.

Fix: a `_connecting` flag set before the await; make `_reconnectAfterDelay`
idempotent and have it cancel only the subscription it owns.

### H5. `watchFolder()` is called inside `build()` — a folder GET per frame while dragging
`lib/features/windows/presentation/folder_window_content.dart:262`

`StreamBuilder(stream: _repo.watchFolder(...))` builds a new `StreamController`
every build. `WindowInstance.props` includes `position`/`size`, so every
pointer move during a drag rebuilds every `DraggableWindow`;
`StreamBuilder.didUpdateWidget` sees a new stream, resubscribes, and
`onListen` fires `refresh()` → `GET /desktop/folder/{id}`.

~60 folder listings per second **per open folder window**, each with a token
round-trip and a DB query.

Fix: build the stream once in `initState`/`didUpdateWidget`, keyed on
`_currentFolder.id`. (`recycle_bin_window_content.dart` has the same shape and
only escapes because its widget is `const`.)

### H6. On web the wallpaper `StorageService` *is* the personal-tree service
`lib/core/di/injector.dart:109-112`

```dart
getIt.registerLazySingleton<StorageService>(
  () => getIt<StorageService>(),
  instanceName: wallpaperInstanceName,
);
```

CLAUDE.md says this split is "kept separate so switching it can never affect
the personal file tree registrations" — the alias makes it literally the same
`ApiStorageService`. `_uploadCustomWallpaper` uploads with no `parentFolderId`
and no `fileName`, so every web wallpaper upload creates a real `FileRecord`
at the root of the personal tree named `1712345678901_photo.png`, i.e. a junk
desktop icon. Windows is unaffected (`LocalWallpaperStorageService`).

Fix: register a real API-backed wallpaper service with its own prefix or a
dedicated hidden folder. Needs a decision on where wallpapers should live
server-side — see O2.

### H7. `SettingsBloc` reaches into `get_it` from inside an event handler
`lib/features/settings/bloc/settings_bloc.dart:2`, `:29-35`

Its constructor takes only `settingsRepository`; `_onLoadRequested` then
resolves `WallpaperRepository`, `StorageService` and `AuthRepository` itself,
hardcoding `wallpaperInstanceName` at the call site. Breaks convention #3 — a
third wallpaper backend can no longer be swapped by re-registering — and makes
this the one bloc that cannot be constructed without a fully populated global
container, so no test can build it.

Fix: constructor-inject all three; pass them from `lib/app/app.dart`.

### H8. `UploadBloc` uses a `get_it` instance name as a server-side owner id
`lib/features/file-system/bloc/upload_bloc.dart:2`, `:30-31`

```dart
final uid = event.isShared ? sharedInstanceName : _authRepository.currentUser?.uid;
```

`sharedInstanceName` is the DI key `'shared'`; it coincides with the backend's
`SHARED_OWNER_ID`. Renaming the DI instance name — a client-side refactor —
would silently change the `ownerId` written by `createFile`. Harmless only
because `ApiFileSystemRepository.createFile` ignores `ownerId`; switch to the
Firestore or fake repository, both of which persist it, and shared uploads get
stamped with the DI key. A correctly-scoped constant already exists at
`file_item_actions.dart:18`.

Fix: promote one shared-owner constant into `core/`, use it in both places,
drop the injector import from the bloc.

---

## Medium — fixed

1. **`.env` force-unwraps** (7 sites: `injector.dart` ×3, `main.dart` ×4).
   New `lib/shared/utils/env.dart` with `requireEnv`/`optionalEnv`; a missing
   key now throws a `StateError` naming it rather than a bare null-check from
   inside `setupDependencies()`.
2. **`currentUser!` force-unwraps** (8 sites). Null guards at each:
   `desktop_page.dart`, `folder_window_content.dart`,
   `search_window_content.dart`, `recycle_bin_window_content.dart`,
   `settings_bloc.dart`, plus a named `_currentOwnerId()` in the injector that
   explains itself when it throws. In `rest_firebase_auth_repository.dart`,
   `_persistSession` now reads all four session fields into locals — the
   existing guard covered `_idToken`/`_currentUser` but **not** the
   `_refreshToken!`/`_expiresAt!` on the next lines, a real latent NPE.
3. **`dart:io` reachable from the web entrypoint** (2 files).
   `local_wallpaper_repository.dart` and `local_wallpaper_storage_service.dart`
   are now conditional-export files over `_io.dart` + `_stub.dart` variants,
   matching `browser_download*`. The compiler enforces the split; it was
   previously only the runtime `kIsWeb` branch in the injector.
4. **`dart.library.html` is the wrong web discriminator** (4 files:
   `browser_download.dart`, `pdf_viewer.dart`, `video_viewer.dart`,
   `adaptive_image_provider.dart`). None of the `_web` variants imports
   `dart:html` — they use `package:web`/`dart:js_interop`. Under `dart2wasm`
   both `dart.library.html` and `dart.library.io` are false, so all four fell
   through to their stubs and `adaptiveImageProvider` would throw
   `UnsupportedError` on the desktop page's image wallpaper path. Switched to
   `dart.library.js_interop`, which is true on both dart2js and dart2wasm.
   The build already prints "Wasm dry run succeeded", so this was one flag
   away.
5. **Settings load dispatched before any user exists** (`app.dart:37-39`).
   `App.initState` added `SettingsLoadRequested` immediately, but no
   `AuthRepository` has a restored user that early on either platform. Removed
   the eager add — the `Authenticated` transition four lines below already
   triggers the load, and `AuthBloc` emits it via `emit.forEach` on the
   restored session. This was the *ordering* behind several of the
   `currentUser!` unwraps.
6. **`reorder` threw `UnimplementedError`**
   (`api_file_system_repository.dart:246`). Every desktop-icon drop on empty
   space took that branch (`parentFolderId` and `containerFolderId` both null),
   throwing an unhandled async error out of the drag handler. Now returns
   `Left(FileSystemFailure(...))` like every other method on the interface —
   the backend has no reorder route yet.
7. **Windows volume slider read/write scale mismatch**
   (`video_viewer_desktop.dart:479` vs `vlc_video_playback_controller.dart`).
   Reads divided `VlcPlayerValue.volume` by 200, writes multiplied by 100, so
   the slider snapped back to half of wherever it was dragged and could never
   show above 50%. Unified on 0..1 → 0..100.
8. **Minimizing a window destroyed its content state**
   (`windows_overlay.dart:15`). Minimized windows were filtered out of the
   `Stack`, unmounting the subtree and disposing its `State` — a folder window
   came back at its root, a video restarted at 00:00, and on Windows the
   `VlcPlayerController` was torn down and rebuilt every minimize/restore.
   They now stay in the tree behind `Offstage` + `TickerMode(enabled: false)`;
   the (stateless) resize handle is still dropped.
9. **A network blip signed the Windows user out**
   (`rest_firebase_auth_repository.dart`). The refresh POST's bare
   `catch (_) { signOut(); }` could not tell a dead refresh token from a
   timeout or captive portal, so a momentary drop wiped the session and
   bounced the router to `/login`, losing every open window. Now only a 4xx
   signs out; concurrent callers crossing the expiry window share one
   in-flight refresh instead of each firing their own.
10. **A window dragged above the top edge became unreachable**
    (`window_bloc.dart:74`). `_onMovedTo` stored the raw position and the pan
    gesture keeps tracking past the window edge, so the title bar could land
    at negative `y`, outside the `Stack`'s hit-test area — unmovable and
    uncloseable, since the taskbar only toggles minimize. Top-left is now
    clamped (the bloc has no viewport size, and the other two edges leave the
    title bar reachable).
11. **`DesktopIconGrid` had no tree injection and a false docstring**
    (`desktop_icon_grid.dart`). Its doc claimed `FolderWindowContent`
    delegates to it; that widget actually hand-rolls its own `Wrap` precisely
    because the grid couldn't carry a tree. Added an optional
    `fileSystemRepository` (the `FolderWindowContent` pattern, defaulting to
    the personal registration so `DesktopPage` is unaffected) and corrected
    the doc.
12. **Drops swallowed their failures** (`desktop_icon_grid.dart`). A `move`
    that 404'd or an unsupported `reorder` just made the icon snap back
    silently; failures now surface in a SnackBar.
13. **CLAUDE.md's `.env` contract was wrong for Windows.** It said the
    `FIREBASE_*` keys are needed "for web"; `RestFirebaseAuthRepository` — the
    **non-web** branch — needs `FIREBASE_API_KEY` too, so a fresh clone
    following the documented minimum crashed on `flutter run -d windows`.

## Medium — open

Each of these changes product behaviour, a public interface, or needs backend
routes, so they are decisions rather than repairs.

### O1. Deleting anything in the Shared folder is unrecoverable
`lib/features/file-system/presentation/recycle_bin_window_content.dart:28`

The Recycle Bin hardcodes the unnamed repository, so it lists only
`/desktop/recycle-bin` (scoped to `user.uid`). Shared deletes soft-delete
under `owner_id = "shared"` and never appear there. Threading the shared repo
in would not help: `../virtual-api/app/api/shared.py` defines no
`recycle-bin`, `restore` or purge routes, so all three calls would 404 — the
client-side fix alone is not possible.

The UI currently promises a recycle bin it does not have: the confirm dialog
says *Move "x" to the Recycle Bin?* (`file_item_actions.dart:102`).

Options: add the three shared routes server-side and give the window a tree
selector; or relabel the shared delete as an explicit permanent delete until
they exist.

### O2. Where should web wallpapers be stored?
Same root cause as H6. Any fix needs a decision: a dedicated `/desktop/wallpapers`
prefix, a hidden `.wallpapers` folder in the personal tree, or a separate
wallpaper upload route on the backend.

### O3. The wallpaper workflow lives in a widget, not `SettingsBloc`
`lib/features/settings/presentation/settings_window_content.dart:71-190`,
`:445-453`, `:504-510`, `:522-531`

`_uploadCustomWallpaper` sequences five repository/service calls
(findExisting → uploadFile → saveWallpaper → updateWallpaper → emit) inside a
`State` method; `SettingsBloc` only receives the resulting URL.
`_WallpaperThumbnail` and `_WallpaperGallery` call the repository and storage
service directly too. A third wallpaper backend has to satisfy a call order
defined in a widget, and none of it is testable without a live container.

Fix: move it behind a `SettingsWallpaperUploadRequested` event. Best done
together with H7.

### O4. Provider-specific storage-key layout is invented in a bloc and in UI
`lib/features/file-system/bloc/upload_bloc.dart:40-41`,
`lib/shared/widgets/file_item_actions.dart:233-234`,
`lib/features/settings/presentation/settings_window_content.dart:130-131`

Three call sites build `users/<owner>/<millis>_<name>` and pass it as
`uploadFile(path:)`. The active provider ignores it except as a filename
fallback — which is exactly why pasted files and web wallpapers land named
`1712345678901_photo.jpg`. `uploadFile` now has two disagreeing ways to say
what a file is called (`path` and `fileName`).

Fix: let the service own key generation; reduce `path` to an opaque handle or
drop it for `fileName` + `parentFolderId`. Entangled with H1 — worth doing in
the same pass.

### O5. `StorageService.uploadFile` carries `bool isShared`
`lib/core/services/storage_service.dart:21`

Which tree you are in is already decided by which registration you resolved
(`sharedInstanceName` / `basePath: '/desktop/shared'`). Two mechanisms for one
fact, used inconsistently: `UploadBloc` passes `isShared: true` *and* runs on
the shared service, while `pasteClipboardItem` omits it and relies on
`basePath`. Server-side the shared upload route does not even accept it.

Fix: drop it from the interface. This is a public-interface change, hence
listed rather than applied.

### O6. Preview stream URLs embed a token that expires mid-playback
`lib/core/providers/api/services/api_storage_service.dart:76`

`getDownloadUrl` bakes the current ID token into `.../stream/{id}?token=...`,
resolved once when the preview window opens. `/desktop/stream/{id}`
re-validates it on every range request and Firebase ID tokens last an hour, so
a long film 401s partway through — a silent failure on web, a generic VLC
error on Windows.

Fix: re-resolve the URL on a stream error, or issue a short-lived
stream-scoped token the player can refresh.

---

## Low — open

Kept as-is; none of these are in the requested scope.

**Correctness / UX**
- Search fires a request per keystroke with no ordering guard, so results can
  settle on a stale query (`search_window_content.dart:35`).
- On web, choosing a subtitle track while paused renders nothing — the view
  listens only to the `VideoPlayerController`, never to the
  `VideoPlaybackController` whose `setSubtitleTrack` notifies. The desktop
  viewer does subscribe; the fix landed on one variant only
  (`video_player_controls.dart:47`).
- Cross-tree drag-and-drop fails silently: both drop handlers call `move()` on
  the *destination* view's repository, which 404s across trees
  (`desktop_icon_grid.dart:41`, `folder_window_content.dart:283`). The
  SnackBar added in this pass now at least surfaces it on the desktop grid.
- A failed video load on web spins forever — no `catchError`, nothing checks
  `value.hasError` (`video_viewer_web.dart:40`). The desktop viewer handles it.
- `audio_viewer.dart:21-26` has three `.listen()` subscriptions that are never
  cancelled and call `setState` with no `mounted` guard.
- `desktop_state.dart:27` — `copyWith` cannot set `currentFolderId` back to
  null, so `DesktopFolderWatchRequested(null)` silently keeps the old id.
  Harmless today only because nothing reads it.
- `_resolveCopyName` numbers copies `name` → `name (copy)` → `name (copy 3)`,
  skipping "(copy 2)" (`file_item_actions.dart:145`).

**Waste**
- Streams opened inside `build()` in `settings_window_content.dart:451` (same
  shape as H5, lower cost).
- Shared-tree events are `broadcast_all`ed with no tree marker, so a create in
  the shared root also refreshes every personal root watcher
  (`api_file_system_repository.dart:55`).

**Dead or drifting code**
- `FoldersApi` is registered in `get_it` but never resolved — the only
  concrete provider class exposed through the container
  (`injector.dart:78-81`).
- Five provider implementations are unregistered and drifting
  (`firestore_file_system_repository.dart`, `firebase_storage_service.dart`,
  `fake_file_system_repository.dart`, `fake_storage_service.dart`,
  `fake_auth_repository.dart`). They have already diverged: two return
  `Right(unit)` from `sync()` where `ApiFileSystemRepository` returns a
  `Failure`.
- `DownloadBloc` and the whole `browser_download*` trio are unreachable —
  `triggerBrowserDownload` has zero call sites and the context menu offers no
  Download action. CLAUDE.md lists downloads as one of the three genuine
  web/Windows divergences, describing a feature the UI never reaches.
- `video_viewer_desktop.dart:40` — `VlcPlayerController` is released only
  indirectly via `_playback` in `dispose()` (the one remaining scanner
  finding).

**Doc drift**
- CLAUDE.md says the VLC wrapper presents "the same controller-shaped API" as
  the web one. It does not: the web controller's methods return `void` where
  VLC's return `Future<void>`, and VLC adds five members. With no shared type,
  `video_viewer_desktop.dart` carries private re-implementations of
  `VideoPlayerView`, `_SubtitleText`, `_TopBar`, `_BottomBar` and
  `_SubtitleMenu`, which have already drifted. The upstream-facing
  `VideoViewer(url, fileName, subtitleTracks)` signature *is* identical across
  all three variants, so `PreviewBloc` is genuinely insulated — the cost is
  that every control change must be made twice.

**Analyzer** — 10 infos, unchanged: `unnecessary_underscores` ×2,
`unintended_html_in_doc_comment`, `use_build_context_synchronously` ×4,
`deprecated_member_use` (Color.value), `curly_braces_in_flow_control_structures` ×2.

---

## Clean

The arch audit confirmed: every interface resolved anywhere in `lib/` is
registered on both platforms — no `kIsWeb` branch without an `else`, and no
unnamed `WallpaperRepository` is ever resolved. Repository and storage-service
implementations do not call each other. The abstract interfaces in
`core/repositories/` and `core/services/` are free of Firestore, Dio and
raw-JSON vocabulary; the only leak is the `isShared` flag (O5). `VideoViewer`
and `PdfViewer` have identical public signatures and nullability across all
three variants.
