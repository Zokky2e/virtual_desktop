import 'package:get_it/get_it.dart';
import 'package:virtual_desktop/core/providers/api/client/api_client.dart';
import 'package:virtual_desktop/core/providers/api/client/api_websocket_client.dart';
import 'package:virtual_desktop/core/providers/api/client/files_api.dart';
import 'package:virtual_desktop/core/providers/api/client/folders_api.dart';
import 'package:virtual_desktop/core/providers/api/client/wallpapers_api.dart';
import 'package:virtual_desktop/core/providers/api/repositories/api_file_system_repository.dart';
import 'package:virtual_desktop/core/providers/api/repositories/api_wallpaper_repository.dart';
import 'package:virtual_desktop/core/providers/api/services/api_storage_service.dart';
import 'package:virtual_desktop/core/providers/api/services/api_wallpaper_storage_service.dart';
import 'package:virtual_desktop/core/providers/firebase/firebase_auth_repository.dart';
import 'package:virtual_desktop/core/providers/local/local_wallpaper_repository.dart';
import 'package:virtual_desktop/core/providers/local/local_wallpaper_storage_service.dart';
import 'package:virtual_desktop/core/providers/local/shared_prefs_settings_repository.dart';
import 'package:virtual_desktop/core/repositories/settings_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/file_system_repository.dart';
import '../services/storage_service.dart';
import '../repositories/wallpaper_repository.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:virtual_desktop/core/providers/rest/rest_firebase_auth_repository.dart';
import 'package:virtual_desktop/shared/utils/env.dart';

final getIt = GetIt.instance;

/// instanceName used for every shared-tree registration below — one
/// constant so callers (taskbar.dart) always resolve the same singletons.
const sharedInstanceName = 'shared';

/// instanceName for wallpaper-specific registrations — Firestore+API on
/// web, local disk on desktop. Kept separate from the default
/// WallpaperRepository/StorageService registrations so this swap can't
/// accidentally affect the personal file tree.
const wallpaperInstanceName = 'wallpaper';

Future<String?> _currentIdToken() => getIt<AuthRepository>().getIdToken();

/// Owner id for per-user settings keys. Settings are only ever read behind
/// the router's auth guard, so a null user here means the guard was bypassed
/// or a sign-out raced the read — fail with a message that says which,
/// rather than a bare null-check error from inside SharedPreferences.
String _currentOwnerId() {
  final user = getIt<AuthRepository>().currentUser;
  if (user == null) {
    throw StateError(
      'Settings were read with no signed-in user. Settings keys are scoped '
      'per user, so there is no correct key to use here — the caller should '
      'be behind the auth guard.',
    );
  }
  return user.uid;
}

void setupDependencies() {
  if (kIsWeb) {
    getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository());
  } else {
    getIt.registerLazySingleton<AuthRepository>(
      () => RestFirebaseAuthRepository(apiKey: requireEnv('FIREBASE_API_KEY')),
    );
  }

  final apiBaseUrl = requireEnv('API_BASE_URL');

  final apiClient = ApiClient(
    baseUrl: apiBaseUrl,
    getIdToken:
        _currentIdToken, // was _currentFirebaseIdToken — now provider-agnostic
  );

  final wsClient = ApiWebSocketClient(
    baseUrl: apiBaseUrl,
    getIdToken: _currentIdToken,
  );

  // The backend binds each /ws connection to the uid in its handshake
  // token, so the socket's lifetime is a sign-in's lifetime — not the
  // process's. Driving it from here (the composition root) rather than
  // from ApiFileSystemRepository's constructor is what makes a second
  // sign-in work: signing out and back in as another user used to leave
  // the first user's socket in place, so nothing live-updated until a
  // restart. Both tree registrations share this one client.
  getIt<AuthRepository>().authStateChanges.listen(
    (user) => wsClient.setOwner(user?.uid),
  );

  // --- Personal tree (basePath '/desktop') — the default, unnamed
  // registrations every existing call site already resolves.
  final foldersApi = FoldersApi(apiClient);
  final filesApi = FilesApi(apiClient);

  getIt.registerLazySingleton<StorageService>(
    () => ApiStorageService(filesApi: filesApi, client: apiClient),
  );
  getIt.registerLazySingleton<FileSystemRepository>(
    () => ApiFileSystemRepository(
      foldersApi: foldersApi,
      filesApi: filesApi,
      wsClient: wsClient,
    ),
  );

  // --- Shared tree (basePath '/desktop/shared') — see
  // shared-folder-flutter-implementation.md. Same server, same
  // ApiClient/WebSocket connection, only the REST prefix differs.
  final sharedFoldersApi = FoldersApi(apiClient, basePath: '/desktop/shared');
  final sharedFilesApi = FilesApi(apiClient, basePath: '/desktop/shared');

  getIt.registerLazySingleton<FoldersApi>(
    () => sharedFoldersApi,
    instanceName: sharedInstanceName,
  );
  getIt.registerLazySingleton<StorageService>(
    () => ApiStorageService(
      filesApi: sharedFilesApi,
      client: apiClient,
      basePath: '/desktop/shared',
    ),
    instanceName: sharedInstanceName,
  );
  getIt.registerLazySingleton<FileSystemRepository>(
    () => ApiFileSystemRepository(
      foldersApi: sharedFoldersApi,
      filesApi: sharedFilesApi,
      wsClient: wsClient,
    ),
    instanceName: sharedInstanceName,
  );

  getIt.registerLazySingleton<SettingsRepository>(
    () => SharedPrefsSettingsRepository(
      getCurrentOwnerId: _currentOwnerId,
    ),
  );
  if (kIsWeb) {
    // Backed by /desktop/wallpapers — its own table and its own storage
    // prefix server-side, so a wallpaper is never a file-tree item.
    //
    // This replaces two things. FirestoreWallpaperRepository, which only
    // ever worked on web and is now unregistered; and, more importantly,
    // a `() => getIt<StorageService>()` alias that made the wallpaper
    // StorageService *literally the personal-tree one*. That alias is why
    // every web wallpaper upload left a junk `<millis>_photo.png` file at
    // the root of the user's desktop, and it contradicted the "kept
    // separate so this swap can't affect the personal file tree
    // registrations" guarantee in CLAUDE.md.
    final wallpapersApi = WallpapersApi(apiClient);
    getIt.registerLazySingleton<WallpaperRepository>(
      () => ApiWallpaperRepository(wallpapersApi: wallpapersApi),
      instanceName: wallpaperInstanceName,
    );
    getIt.registerLazySingleton<StorageService>(
      () => ApiWallpaperStorageService(
        wallpapersApi: wallpapersApi,
        client: apiClient,
      ),
      instanceName: wallpaperInstanceName,
    );
  } else {
    getIt.registerLazySingleton<WallpaperRepository>(
      () => LocalWallpaperRepository(),
      instanceName: wallpaperInstanceName,
    );
    getIt.registerLazySingleton<StorageService>(
      () => LocalWallpaperStorageService(),
      instanceName: wallpaperInstanceName,
    );
  }
}
