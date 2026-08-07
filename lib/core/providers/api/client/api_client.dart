import 'package:dio/dio.dart';

/// Thin Dio wrapper shared by FoldersApi/FilesApi. Owns the base URL and
/// automatically attaches the current Firebase ID token as a Bearer
/// header on every request — repositories/services never touch auth
/// directly.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required Future<String?> Function() getIdToken,
    Dio? dio,
  }) : _baseUrl = baseUrl,
       _getIdToken = getIdToken,
       _dio = dio ?? Dio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final String _baseUrl;
  final Future<String?> Function() _getIdToken;
  final Dio _dio;

  Dio get dio => _dio;
  String get baseUrl => _baseUrl;

  /// Exposed for callers that need to embed the token in a URL rather
  /// than a header — image/video/PDF widgets that can't attach one.
  Future<String?> get currentIdToken => _getIdToken();
}
