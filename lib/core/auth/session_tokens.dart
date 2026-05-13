import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:okakchat/core/auth/auth_errors.dart';
import 'package:okakchat/core/auth/token_storage.dart';

Future<String?>? _refreshInFlight;

Future<String?> getValidAccessToken(String baseUrl) async {
  final access = await TokenStorage.getAccessToken();
  if (access != null && !_isJwtExpiring(access)) return access;

  final refreshed = await refreshAccessToken(baseUrl);
  if (refreshed != null) return refreshed;

  if (access != null && !_isJwtExpired(access)) return access;
  return null;
}

Future<String?> refreshAccessToken(String baseUrl) {
  final inFlight = _refreshInFlight;
  if (inFlight != null) return inFlight;

  final refresh = _refreshAccessToken(baseUrl);
  _refreshInFlight = refresh;
  refresh.whenComplete(() => _refreshInFlight = null);
  return refresh;
}

Future<String?> _refreshAccessToken(String baseUrl) async {
  final refresh = await TokenStorage.getRefreshToken();
  if (refresh == null) return null;

  try {
    final res = await Dio().post(
      '$baseUrl/api/auth/refresh',
      data: {'refreshToken': refresh},
    );
    final newAccess = res.data['accessToken'] as String;
    final newRefresh = res.data['refreshToken'] as String;
    await TokenStorage.saveTokens(newAccess, newRefresh);
    return newAccess;
  } catch (_) {
    await TokenStorage.clear();
    notifyTokenExpired();
    return null;
  }
}

bool _isJwtExpiring(String token) {
  final expiresAt = _jwtExpiresAt(token);
  if (expiresAt == null) return false;
  return !expiresAt.isAfter(
    DateTime.now().toUtc().add(const Duration(seconds: 30)),
  );
}

bool _isJwtExpired(String token) {
  final expiresAt = _jwtExpiresAt(token);
  if (expiresAt == null) return false;
  return !expiresAt.isAfter(DateTime.now().toUtc());
}

DateTime? _jwtExpiresAt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    final exp = payload['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
  } catch (_) {
    return null;
  }
}
