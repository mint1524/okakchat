import 'package:dio/dio.dart';
import 'package:okakchat/core/auth/session_tokens.dart';
import 'package:okakchat/core/auth/token_storage.dart';

const apiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:80');

Dio createApiClient(String baseUrl) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await TokenStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        final newAccess = await refreshAccessToken(baseUrl);
        if (newAccess != null) {
          error.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retried = await dio.fetch(error.requestOptions);
          return handler.resolve(retried);
        }
      }
      handler.next(error);
    },
  ));

  return dio;
}

final _dioInstance = createApiClient(apiBaseUrl);
Dio get globalDio => _dioInstance;
