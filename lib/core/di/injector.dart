import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:virtual_desktop/core/providers/api/client/api_client.dart';
import 'package:virtual_desktop/core/providers/api/client/api_websocket_client.dart';
import 'package:virtual_desktop/core/providers/api/client/files_api.dart';
import 'package:virtual_desktop/core/providers/api/client/folders_api.dart';
import 'package:virtual_desktop/core/providers/api/repositories/api_file_system_repository.dart';
import 'package:virtual_desktop/core/providers/api/services/api_storage_service.dart';
import 'package:virtual_desktop/core/providers/firebase/firebase_auth_repository.dart';
import 'package:virtual_desktop/core/providers/firebase/firestore_wallpaper_repository.dart';
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

void setupDependencies() {
  if (kIsWeb) {
    getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository());
  } else {
    getIt.registerLazySingleton<AuthRepository>(
      () => RestFirebaseAuthRepository(apiKey: dotenv.env['FIREBASE_API_KEY']!),
    );
  }

  final apiClient = ApiClient(
    baseUrl: dotenv.env['API_BASE_URL']!,
    getIdToken:
        _currentIdToken, // was _currentFirebaseIdToken — now provider-agnostic
  );

  final wsClient = ApiWebSocketClient(
    baseUrl: dotenv.env['API_BASE_URL']!,
    getIdToken: _currentIdToken,
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
      getCurrentOwnerId: () => getIt<AuthRepository>().currentUser!.uid,
    ),
  );
  if (kIsWeb) {
    getIt.registerLazySingleton<WallpaperRepository>(
      () => FirestoreWallpaperRepository(),
      instanceName: wallpaperInstanceName,
    );
    getIt.registerLazySingleton<StorageService>(
      () => getIt<StorageService>(),
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
