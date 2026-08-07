import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:dio/dio.dart';
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
import 'package:virtual_desktop/core/providers/local/shared_prefs_settings_repository.dart';
import 'package:virtual_desktop/core/repositories/settings_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/file_system_repository.dart';
import '../services/storage_service.dart';
import '../repositories/wallpaper_repository.dart';

final getIt = GetIt.instance;

Future<String?> _currentFirebaseIdToken() =>
    getIt<AuthRepository>().currentUser != null
    // FirebaseAuthRepository doesn't expose getIdToken directly —
    // simplest is to reach the SDK once, here, at the DI boundary
    // rather than growing AuthRepository's interface for one caller.
    ? _firebaseIdToken()
    : Future.value(null);

Future<String?> _firebaseIdToken() async {
  // ignore: implementation_imports
  final user = fb.FirebaseAuth.instance.currentUser;
  return user?.getIdToken();
}

void setupDependencies() {
  getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository());

  // --- Self-hosted API provider (swap back to Firebase by re-pointing
  // these two registrations at FirebaseStorageService /
  // FirestoreFileSystemRepository — no BLoC/UI changes needed either way).
  final apiClient = ApiClient(
    baseUrl: dotenv.env['API_BASE_URL']!,
    getIdToken: _currentFirebaseIdToken,
  );
  final foldersApi = FoldersApi(apiClient);
  final filesApi = FilesApi(apiClient);
  final wsClient = ApiWebSocketClient(
    baseUrl: dotenv.env['API_BASE_URL']!,
    getIdToken: _currentFirebaseIdToken,
  );

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

  getIt.registerLazySingleton<SettingsRepository>(
    () => SharedPrefsSettingsRepository(
      getCurrentOwnerId: () => getIt<AuthRepository>().currentUser!.uid,
    ),
  );
  getIt.registerLazySingleton<WallpaperRepository>(
    () => FirestoreWallpaperRepository(),
  );
}
