import 'package:fpdart/fpdart.dart';
import '../error/failure.dart';
import '../models/app_user.dart';

abstract class AuthRepository {
  /// Emits the current user, or null when signed out.
  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;

  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, AppUser>> signUp({
    required String email,
    required String password,
  });

  Future<Either<Failure, Unit>> signOut();

  /// A valid (refreshed if necessary) ID token for backend calls, or null
  /// if signed out. Callers (ApiClient, ApiWebSocketClient) go through
  /// this instead of touching any SDK directly — keeps them provider-
  /// agnostic the same way FileSystemRepository/StorageService already are.
  Future<String?> getIdToken();
}
