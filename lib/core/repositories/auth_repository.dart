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
}
