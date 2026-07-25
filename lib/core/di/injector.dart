import 'package:get_it/get_it.dart';
import 'package:virtual_desktop/core/providers/firebase/firebase_auth_repository.dart';
import 'package:virtual_desktop/core/providers/firebase/firestore_file_system_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/file_system_repository.dart';
import '../services/storage_service.dart';
import '../providers/local/fake_storage_service.dart';
import '../providers/local/fake_file_system_repository.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // --- Phase 3: fakes. Swap these one line at a time in later phases. ---
  getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository());
  getIt.registerLazySingleton<StorageService>(() => FakeStorageService());
  getIt.registerLazySingleton<FileSystemRepository>(
    () => FirestoreFileSystemRepository(
      getCurrentOwnerId: () => getIt<AuthRepository>().currentUser!.uid,
    ),
  );
}
