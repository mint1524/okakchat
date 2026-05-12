import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/api/api_client.dart';
import 'package:okakchat/core/api/auth_api.dart';
import 'package:okakchat/core/auth/token_storage.dart';

final dioProvider = Provider((ref) => globalDio);
final authApiProvider = Provider((ref) => AuthApi(ref.watch(dioProvider)));

class AuthUser {
  const AuthUser({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.isAdmin,
  });
  final String userId, email, displayName;
  final bool isAdmin;
}

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return null;
    try {
      final me = await ref.read(authApiProvider).getMe();
      return _meToUser(me);
    } catch (_) {
      await TokenStorage.clear();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final data = await ref.read(authApiProvider).login(email, password);
      await TokenStorage.saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      final me = await ref.read(authApiProvider).getMe();
      state = AsyncData(_meToUser(me));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<({String userId, String email})> register(
      String email, String password, String displayName) async {
    final data =
        await ref.read(authApiProvider).register(email, password, displayName);
    return (userId: data['userId'] as String, email: email);
  }

  Future<void> verify(String userId, String code) async {
    state = const AsyncLoading();
    try {
      final data = await ref.read(authApiProvider).verify(userId, code);
      await TokenStorage.saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      final me = await ref.read(authApiProvider).getMe();
      state = AsyncData(_meToUser(me));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> logout() async {
    final refresh = await TokenStorage.getRefreshToken();
    if (refresh != null) {
      try {
        await ref.read(authApiProvider).logout(refresh);
      } catch (_) {}
    }
    await TokenStorage.clear();
    state = const AsyncData(null);
  }

  AuthUser _meToUser(Map<String, dynamic> me) => AuthUser(
        userId: me['userId'] as String,
        email: me['email'] as String,
        displayName: me['displayName'] as String,
        isAdmin: me['isAdmin'] as bool,
      );
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthUser?>(() => AuthNotifier());
