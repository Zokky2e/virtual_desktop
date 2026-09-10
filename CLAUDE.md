# Virtual Desktop (Flutter frontend)

This is the **frontend half** of a two-repo system. The **backend half lives in
a sibling folder**: `../virtual-api` (FastAPI). When a task touches the API
contract, auth, storage, or WebSocket events, read the relevant files there
too — do not guess the backend's behavior from this repo alone.

`../virtual-api/CLAUDE.md` has the backend-side equivalent of this file.

## What this app is

A single Flutter codebase that ships as **two real targets**, not "web with a
desktop wrapper": a **Flutter Web app** and a **native Windows desktop app**
(`flutter run -d windows` / `flutter build windows`, backed by the `windows/`
platform folder — the standard Flutter Windows embedder/runner project).
Both targets mimic a desktop environment: sign in, manage folders/files, open
multiple draggable/resizable windows, and preview files (image/video/audio/
PDF/text/JSON/markdown) directly from cloud/server storage without
downloading.

The two targets share the vast majority of the codebase (BLoCs, UI widgets,
window management, the API client) but genuinely diverge at the platform
boundary wherever the underlying OS/browser capabilities differ — video
decoding, image loading, file downloads, and (critically) authentication all
have separate Windows-specific implementations rather than one browser-only
code path. See "Platform-conditional files" and "Known constraints" below
for exactly where and why.

`android/`, `ios/`, `linux/`, and `macos/` also exist at the repo root as
default Flutter platform scaffolding (created by `flutter create`) but are
not actively targeted or maintained — treat Web and Windows as the two real
platforms for this project unless told otherwise.

## Tech stack

- Flutter Web **and** Flutter Windows desktop — two actively maintained
  targets sharing one codebase
- `flutter_bloc` (BLoC pattern) + `equatable`
- `go_router` for navigation
- `get_it` for dependency injection
- `dio` / raw `http` via a custom `ApiClient`
- `firebase_auth` — used for authentication, but **web-only**; Windows uses a
  REST-based Firebase auth implementation instead (see below)
- `flutter_dotenv` — config from `.env` (not committed; see `.gitignore`)
- `video_player` (web, delegates to the browser's `<video>` element) /
  `flutter_vlc_player` aka `vlc_player` (Windows, bundles its own decoders
  via libVLC — see the dedicated section below)
- `web_socket_channel` for the live-update WebSocket connection, used
  identically on both platforms

Run `flutter pub get` after pulling; check `pubspec.yaml` for the exact
version pins before assuming a package API.

## Architecture: depend on interfaces, not providers

Strict layering, enforced project-wide:

```
UI → BLoCs → Repository interfaces → Service interfaces → provider implementations
```

- BLoCs/Cubits never touch Firebase SDK or HTTP clients directly.
- Every repository/service is an abstract interface in `lib/core/repositories/`
  or `lib/core/services/`, with concrete implementations under
  `lib/core/providers/<provider>/`.
- The app **originally** used Firebase (Auth + Firestore + Storage) as the
  only provider. It has since grown a second, now-primary provider: a
  self-hosted REST + WebSocket API (`lib/core/providers/api/`) talking to the
  `virtual-api` backend. A `local`/`fake` provider set exists for
  tests/desktop fallbacks, and `rest/rest_firebase_auth_repository.dart`
  handles Firebase-token auth on platforms where the `firebase_auth` plugin
  itself isn't available (see Windows note below).
- Which provider is active is wired in `lib/core/di/injector.dart` via
  `get_it`, generally gated on `kIsWeb` or `.env` values (`API_BASE_URL`,
  Firebase keys). **Read `injector.dart` before assuming which concrete class
  backs an interface** — it changes by platform.

## Folder structure (actual, under `lib/`)

```
lib/
  main.dart                 # entrypoint: Firebase init (web only), dotenv, setupDependencies()
  app/                       # App widget, go_router setup
  core/
    di/injector.dart         # get_it registrations — the source of truth for "which impl is active"
    error/
    models/                  # FileItem, AppUser, AppSettings, WallpaperItem
    repositories/            # abstract interfaces (AuthRepository, FileSystemRepository, ...)
    services/                # abstract interfaces (StorageService, ...)
    providers/
      api/                   # REST/WebSocket provider — talks to virtual-api
        client/              # ApiClient, ApiWebSocketClient, FilesApi, FoldersApi
        models/              # response <-> domain mappers
        repositories/        # ApiFileSystemRepository, ApiWallpaperRepository
        services/            # ApiStorageService, ApiWallpaperStorageService
      firebase/              # Firestore/Firebase Storage/Firebase Auth implementations
      local/                 # fakes + local-disk wallpaper storage (non-web)
      rest/                  # RestFirebaseAuthRepository (Firebase auth over REST, no plugin)
  features/
    authentication/          # login/register, AuthBloc
    desktop/                 # desktop icon grid, wallpaper, DesktopBloc
    windows/                 # draggable/resizable window chrome, WindowBloc, taskbar
    file-system/             # folder browsing, upload/download BLoCs, clipboard, recycle bin, search
    preview/                 # file preview window + per-type viewers (see below)
    settings/
  shared/
    theme/
    utils/                   # mime detection, sort order, platform-conditional download helpers
    widgets/                 # platform-conditional image provider, file item context-menu actions
```

Note: the original architecture doc used the name `filesystem/`; the actual
feature folder is `file-system/` (hyphenated). Trust the folder structure
above (read from the live repo), not older planning docs, when they conflict.

## Personal tree vs. Shared tree

Two parallel `FileSystemRepository`/`StorageService` registrations exist in
`get_it`:

- Unnamed (default) registration → the calling user's own folder tree,
  backend base path `/desktop`. This is what nearly every existing call site
  resolves via plain `getIt<FileSystemRepository>()`.
- `instanceName: sharedInstanceName` (`'shared'`, constant in
  `injector.dart`) → a tree owned by nobody in particular, backend base path
  `/desktop/shared`. Surfaced in the UI as a permanent taskbar icon (like
  Search / Recycle Bin — not a real `FileItem`, hardcoded in `taskbar.dart`).

When adding a new call site that needs "whichever tree is currently open,
personal or shared," thread the repository/service in via constructor
injection (the pattern `FolderWindowContent` uses) rather than reaching into
`getIt` with a hardcoded instance name — see
`shared-folder-flutter-implementation.md` in the project's docs for the full
design rationale if you need it.

There's a similar `instanceName: wallpaperInstanceName` (`'wallpaper'`) split
for the wallpaper repository/service — kept separate so switching it can never
affect the personal file tree registrations. On web it resolves to
`ApiWallpaperRepository` / `ApiWallpaperStorageService`, backed by the
backend's `/desktop/wallpapers` routes; on desktop, to the local-disk pair.

A wallpaper is deliberately **not** a file-tree item. It has its own table
(`wallpapers`) and its own storage prefix (`wallpapers/{uid}/`, outside the
`users/` subtree `ReconcileService` scans) on the server, so a wallpaper can
never appear as a desktop icon or be swept into the tree by a sync. The web
registration used to be a literal alias — `() => getIt<StorageService>()` —
which made that separation untrue and dropped a junk `<millis>_photo.png`
into the root of the user's tree on every wallpaper upload. Don't reintroduce
an alias here.

`FirestoreWallpaperRepository` is no longer registered anywhere as a result.
It still compiles but has joined the other unregistered Firebase provider
implementations; wallpapers saved to Firestore by an older web build are not
migrated and won't appear in the gallery.

## Platform-conditional files (web vs. Windows desktop)

Several features ship as a `foo.dart` conditional-export file plus
`foo_web.dart` / `foo_desktop.dart` / `foo_stub.dart` (or `_io.dart`)
variants — e.g. `features/preview/presentation/viewers/video_viewer*.dart`,
`shared/widgets/adaptive_image_provider*.dart`,
`shared/utils/browser_download*.dart`. This is the project's answer to
"web build uses browser APIs, desktop build uses native ones, but upstream
code — BLoCs, `PreviewBloc`, window content — should never know which."
When changing behavior for one platform, edit only that platform's `_web`/
`_desktop` file; the public widget/function signature in the non-suffixed
file must stay unchanged for the other platform.

Video playback specifically: web uses `video_player` (delegates to the
browser's native `<video>` element — codec support is whatever the browser
supports); Windows desktop uses `flutter_vlc_player` (bundles its own
decoders via libVLC/FFmpeg, so `.mkv`/HEVC/DTS play natively without a
server-side transcode). See "Known constraints" below for the tradeoff this
introduced.

Concrete inventory of components that exist **only** for the Windows target
(not exhaustive — grep for `_desktop`/`_io` suffixes and `!kIsWeb` checks for
more):

- `core/providers/rest/rest_firebase_auth_repository.dart` — Windows has no
  usable `firebase_auth` plugin, so auth goes through Firebase's REST
  identity API directly instead of the SDK (see `firebase/` provider, which
  stays web-only).
- `features/preview/presentation/viewers/video_viewer_desktop.dart` — VLC
  player integration, wrapped by `vlc_video_playback_controller.dart`.
  Note that this wrapper is **not** interchangeable with the web
  `VideoPlaybackController`, despite the parallel naming: its methods
  return `Future<void>` where the web one returns `void`, and it adds
  five members the other doesn't have. There is no shared supertype, so
  `video_viewer_desktop.dart` carries private re-implementations of
  `VideoPlayerView`, `_SubtitleText`, `_TopBar`, `_BottomBar` and
  `_SubtitleMenu` rather than reusing `video_player_controls.dart`.
  Those have already drifted — embedded subtitles exist only on desktop
  — so **assume any change to playback chrome has to be made twice**,
  and check the other variant before calling such a change done.

  What *is* genuinely identical is the upstream-facing
  `VideoViewer(url, fileName, subtitleTracks)` constructor across all
  three variants, which is what keeps `PreviewBloc` insulated.
- `features/preview/presentation/viewers/pdf_viewer_desktop.dart` — native
  PDF rendering path distinct from `pdf_viewer_web.dart`.
- `shared/widgets/adaptive_image_provider_io.dart` — non-web image loading
  (`dart:io`-based) versus `adaptive_image_provider_web.dart`.
- `shared/utils/browser_download_desktop.dart` — "download a file" on
  Windows means writing to disk, not triggering a browser download.
- `core/providers/local/local_wallpaper_repository.dart` and
  `local_wallpaper_storage_service.dart` — wallpaper storage on local disk,
  used instead of the Firestore/API-backed wallpaper provider when
  `!kIsWeb`.

## Talking to the backend (`virtual-api`)

- Base URL comes from `.env`'s `API_BASE_URL`.
- Every request is authenticated with `Authorization: Bearer <firebase-id-token>`
  (`ApiClient`'s `getIdToken` callback, backed by whichever `AuthRepository`
  is active).
- REST endpoints live under `/desktop` (personal) and `/desktop/shared`
  (shared tree) — folders, files, upload, download, streaming, rename, move,
  delete, search, recycle bin. WebSocket is `/ws`, outside the REST prefix,
  and pushes live `file_created`/`file_deleted`/`file_renamed`/etc. events so
  the UI never has to poll.
- `/desktop/wallpapers` is a third prefix, and not a file tree: list, upload,
  `stream/{id}`, `{id}`, and `PATCH {id}/active`. It has its own table and
  storage prefix, and deliberately emits **no** WebSocket events — the client
  refetches after its own mutations instead (`ApiWallpaperRepository`).
- The `/ws` socket is bound server-side to the uid in its handshake token, so
  it can't outlive a sign-in. `injector.dart` owns that lifecycle against
  `authStateChanges` — never call `connect()` from a repository constructor,
  which is what previously broke live updates after a sign-out/sign-in.
- Full endpoint list and request/response shapes: see `../virtual-api`'s
  `app/api/*.py` routers directly, or this project's
  `Virtual_Desktop_Server_Architecture.md` / `API_Provider_Architecture.md`
  docs for the design rationale.

## Known constraints / active tradeoffs

- **Firebase on Windows desktop is unsupported.** `firebase_auth`,
  `cloud_firestore`, and `firebase_storage` have no official Windows target,
  so `FirebaseAuthRepository` / `FirestoreWallpaperRepository` don't work
  there as-is — this is why `RestFirebaseAuthRepository` exists. Any
  Windows-targeted change touching auth or wallpaper needs to go through the
  REST/local providers, not the Firebase ones. (Wallpapers no longer use
  Firebase on either target — see the `wallpaperInstanceName` note above.)
- **VLC (Windows video playback) CPU usage is an open risk**, not yet
  confirmed problematic. If profiling shows a core pinned near 100% during
  normal 1080p playback, or high CPU while paused/idle, the documented
  fallback order is `media_kit` (libmpv) first, then `fvp` (libmdk backend
  for the *official* `video_player` API — smallest diff). Don't silently
  swap the video backend without checking this tradeoff first.
- Recursive folder copy is intentionally unsupported (`pasteClipboardItem`) —
  this is a deliberate scope cut, not a bug.

## Dev commands

```
flutter pub get
flutter run -d chrome        # web target
flutter run -d windows       # desktop target
flutter test
flutter analyze
```

Requires a `.env` file (git-ignored) with at least `API_BASE_URL` and
`FIREBASE_API_KEY` — the latter is needed on **both** targets, not just web:
`RestFirebaseAuthRepository` (the Windows auth path) takes it too. The
remaining `FIREBASE_*` keys read in `main.dart` are web-only. Read required
keys through `requireEnv()` in `lib/shared/utils/env.dart`, which names the
missing key instead of throwing a bare null-check error at startup.

## Scanning for issues

```
dart run tool/scan.dart            # project-aware static scan
dart run tool/scan.dart --analyze  # merge `flutter analyze` into the same report
dart run tool/scan.dart --json     # machine-readable
```

`tool/scan.dart` encodes the rules in this file — layering, `get_it` instance
names, platform-conditional file parity, disposal, `.env` force-unwraps — as
checks the analyzer cannot express. Its header comment lists the flags; the
groups are `arch`, `platform`, `lifecycle`, `runtime`, `hygiene`, and it exits
1 when anything high-severity is present. Run it after changes that touch
layering or the web/Windows split. When a bug class shows up twice, add a rule
there rather than re-explaining it each session.

The deeper pass is agent-driven: `/scan-issues` runs the static passes, then
dispatches the `flutter-bug-hunter` (runtime races, wrong-tree reads, state
bugs) and `flutter-arch-auditor` (convention drift, DI wiring, variant parity)
agents and merges everything into one ranked report. Definitions live in
`.claude/agents/`.

Standing baseline: `test/widget_test.dart` is still the stale `flutter create`
counter test and fails. It is a known failure, not a regression.

## Conventions to preserve when editing

1. Never let a BLoC/Cubit import a provider implementation directly — only
   the abstract repository/service interface.
2. Never let repository and storage-service implementations call each other
   — both depend on shared lower-level API clients instead (see
   `API_Provider_Architecture.md`).
3. New provider implementations (a third storage backend, etc.) should be
   registerable in `get_it` with zero changes to BLoCs or UI.
4. Keep the personal-tree unnamed `getIt` registrations working unchanged —
   most of the app depends on them resolving with no `instanceName`.
