import 'package:get_it/get_it.dart';
import '../repositories/auth_repository.dart';
import '../repositories/file_system_repository.dart';
import '../services/storage_service.dart';
import '../providers/local/fake_auth_repository.dart';
import '../providers/local/fake_storage_service.dart';
import '../providers/local/fake_file_system_repository.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // --- Phase 3: fakes. Swap these one line at a time in later phases. ---
  getIt.registerLazySingleton<AuthRepository>(() => FakeAuthRepository());
  getIt.registerLazySingleton<StorageService>(() => FakeStorageService());
  getIt.registerLazySingleton<FileSystemRepository>(
    () => FakeFileSystemRepository(),
  );
}
