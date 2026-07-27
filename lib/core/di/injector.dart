import 'package:get_it/get_it.dart';
import 'package:virtual_desktop/core/providers/firebase/firebase_auth_repository.dart';
import 'package:virtual_desktop/core/providers/firebase/firebase_storage_service.dart';
import 'package:virtual_desktop/core/providers/firebase/firestore_wallpaper_repository.dart';
import 'package:virtual_desktop/core/providers/firebase/firestore_file_system_repository.dart';
import 'package:virtual_desktop/core/providers/local/shared_prefs_settings_repository.dart';
import 'package:virtual_desktop/core/repositories/settings_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/file_system_repository.dart';
import '../services/storage_service.dart';
import '../repositories/wallpaper_repository.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // --- Phase 3: fakes. Swap these one line at a time in later phases. ---
  getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository());
  getIt.registerLazySingleton<StorageService>(() => FirebaseStorageService());
  getIt.registerLazySingleton<FileSystemRepository>(
    () => FirestoreFileSystemRepository(
      getCurrentOwnerId: () => getIt<AuthRepository>().currentUser!.uid,
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
