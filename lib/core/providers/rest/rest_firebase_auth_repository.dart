// lib/core/providers/rest/rest_firebase_auth_repository.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../error/failure.dart';
import '../../models/app_user.dart';
import '../../repositories/auth_repository.dart';

/// Windows/Linux/macOS AuthRepository — talks directly to Firebase's
/// Identity Toolkit REST API instead of the firebase_auth plugin, which
/// has no official desktop support (see
/// Windows-Desktop-Video-Player-VLC-Plan.md's "Related, larger blocker").
/// Same public contract as FirebaseAuthRepository, so AuthBloc/router
/// never know which one is behind getIt<AuthRepository>().
///
/// Tokens persist via SharedPreferences so a session survives restarts.
/// SharedPreferences is plaintext on disk — fine for a self-hosted single-
/// user desktop app, but swap for flutter_secure_storage if that ever
/// stops being true.
class RestFirebaseAuthRepository implements AuthRepository {
  RestFirebaseAuthRepository({required String apiKey, Dio? dio})
    : _apiKey = apiKey,
      _dio = dio ?? Dio();

  static const _identityToolkitBase =
      'https://identitytoolkit.googleapis.com/v1/accounts';
  static const _secureTokenBase = 'https://securetoken.googleapis.com/v1/token';

  static const _kIdToken = 'rest_auth.idToken';
  static const _kRefreshToken = 'rest_auth.refreshToken';
  static const _kExpiresAt = 'rest_auth.expiresAt';
  static const _kUid = 'rest_auth.uid';
  static const _kEmail = 'rest_auth.email';

  final String _apiKey;
  final Dio _dio;
  final _controller = StreamController<AppUser?>.broadcast();

  AppUser? _currentUser;
  String? _idToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  bool _restored = false;

  @override
  Stream<AppUser?> get authStateChanges async* {
    if (!_restored) await _restoreSession();
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _currentUser;

  Future<void> _restoreSession() async {
    _restored = true;
    final prefs = await SharedPreferences.getInstance();
    final idToken = prefs.getString(_kIdToken);
    final refreshToken = prefs.getString(_kRefreshToken);
    final expiresAtMs = prefs.getInt(_kExpiresAt);
    final uid = prefs.getString(_kUid);
    final email = prefs.getString(_kEmail);
    if (idToken == null ||
        refreshToken == null ||
        uid == null ||
        email == null) {
      return;
    }
    _idToken = idToken;
    _refreshToken = refreshToken;
    _expiresAt = expiresAtMs != null
        ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
        : DateTime.now();
    _currentUser = AppUser(uid: uid, email: email);
    _controller.add(_currentUser);
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_idToken == null || _currentUser == null) {
      await Future.wait([
        prefs.remove(_kIdToken),
        prefs.remove(_kRefreshToken),
        prefs.remove(_kExpiresAt),
        prefs.remove(_kUid),
        prefs.remove(_kEmail),
      ]);
      return;
    }
    await Future.wait([
      prefs.setString(_kIdToken, _idToken!),
      prefs.setString(_kRefreshToken, _refreshToken!),
      prefs.setInt(_kExpiresAt, _expiresAt!.millisecondsSinceEpoch),
      prefs.setString(_kUid, _currentUser!.uid),
      prefs.setString(_kEmail, _currentUser!.email),
    ]);
  }

  Future<void> _applyAuthResult(
    Map<String, dynamic> data,
    String fallbackEmail,
  ) async {
    _idToken = data['idToken'] as String;
    _refreshToken = data['refreshToken'] as String;
    _expiresAt = DateTime.now().add(
      Duration(seconds: int.parse(data['expiresIn'] as String) - 60),
    );
    _currentUser = AppUser(
      uid: data['localId'] as String,
      email: data['email'] as String? ?? fallbackEmail,
    );
    _restored = true;
    await _persistSession();
    _controller.add(_currentUser);
  }

  @override
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  }) => _authRequest(':signInWithPassword', email, password);

  @override
  Future<Either<Failure, AppUser>> signUp({
    required String email,
    required String password,
  }) => _authRequest(':signUp', email, password);

  Future<Either<Failure, AppUser>> _authRequest(
    String endpoint,
    String email,
    String password,
  ) async {
    try {
      final res = await _dio.post(
        '$_identityToolkitBase$endpoint?key=$_apiKey',
        data: {'email': email, 'password': password, 'returnSecureToken': true},
      );
      await _applyAuthResult(res.data as Map<String, dynamic>, email);
      return Right(_currentUser!);
    } on DioException catch (e) {
      return Left(AuthFailure(_describeAuthError(e)));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    _idToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _currentUser = null;
    await _persistSession();
    _controller.add(null);
    return const Right(unit);
  }

  @override
  Future<String?> getIdToken() async {
    if (!_restored) await _restoreSession();
    if (_idToken == null || _refreshToken == null) return null;
    if (_expiresAt != null && DateTime.now().isBefore(_expiresAt!)) {
      return _idToken;
    }
    try {
      final res = await _dio.post(
        '$_secureTokenBase?key=$_apiKey',
        data: {'grant_type': 'refresh_token', 'refresh_token': _refreshToken},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = res.data as Map<String, dynamic>;
      _idToken = data['id_token'] as String;
      _refreshToken = data['refresh_token'] as String;
      _expiresAt = DateTime.now().add(
        Duration(seconds: int.parse(data['expires_in'] as String) - 60),
      );
      await _persistSession();
      return _idToken;
    } catch (_) {
      // Refresh token itself is dead — force a sign-out so the router
      // bounces to /login instead of every API call silently 401ing.
      await signOut();
      return null;
    }
  }

  String _describeAuthError(DioException e) {
    final message = (e.response?.data as Map?)?['error']?['message'] as String?;
    switch (message) {
      case 'EMAIL_NOT_FOUND':
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'EMAIL_EXISTS':
        return 'An account with this email already exists.';
      default:
        return message ?? 'Authentication failed.';
    }
  }
}
