import 'package:dio/dio.dart';

class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> register(
      String email, String password, String displayName) async {
    final res = await _dio.post('/api/auth/register', data: {
      'email': email,
      'password': password,
      'displayName': displayName,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verify(String userId, String code) async {
    final res = await _dio.post('/api/auth/verify',
        data: {'userId': userId, 'code': code});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String email, String password,
      {String? deviceInfo}) async {
    final res = await _dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/api/auth/logout', data: {'refreshToken': refreshToken});
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/api/auth/me');
    return res.data as Map<String, dynamic>;
  }
}
