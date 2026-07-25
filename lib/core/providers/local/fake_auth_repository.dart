import 'dart:async';
import 'package:fpdart/fpdart.dart';
import '../../error/failure.dart';
import '../../models/app_user.dart';
import '../../repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  AppUser? _currentUser;
  final _controller = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    final user = AppUser(uid: 'fake-uid', email: email);
    _currentUser = user;
    _controller.add(user);
    return Right(user);
  }

  @override
  Future<Either<Failure, AppUser>> signUp({
    required String email,
    required String password,
  }) async {
    return signIn(email: email, password: password);
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    _currentUser = null;
    _controller.add(null);
    return const Right(unit);
  }
}
