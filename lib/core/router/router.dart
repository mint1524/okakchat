import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/features/auth/login_screen.dart';
import 'package:okakchat/features/auth/register_screen.dart';
import 'package:okakchat/features/auth/verify_screen.dart';
import 'package:okakchat/features/shell/app_shell.dart';

// Stub screens — will be replaced in later tasks
class _ChatStub extends StatelessWidget {
  const _ChatStub({this.conversationId});
  final String? conversationId;
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Chat')));
}
class _HistoryStub extends StatelessWidget {
  const _HistoryStub();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('History')));
}
class _SettingsStub extends StatelessWidget {
  const _SettingsStub();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Settings')));
}
class _AdminStub extends StatelessWidget {
  const _AdminStub();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Admin')));
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  return GoRouter(
    initialLocation: '/chat',
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isLoading = authState.isLoading;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (isLoading) return null;
      if (!isAuthenticated && !isAuthRoute) return '/auth/login';
      if (isAuthenticated && isAuthRoute) return '/chat';
      return null;
    },
    routes: [
      GoRoute(
          path: '/auth/login',
          builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/auth/register',
          builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/auth/verify',
          builder: (_, state) => VerifyScreen(
                userId: state.uri.queryParameters['userId'] ?? '',
                email: state.uri.queryParameters['email'] ?? '',
              )),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
              path: '/chat',
              builder: (_, __) => const _ChatStub()),
          GoRoute(
              path: '/chat/:id',
              builder: (_, state) =>
                  _ChatStub(conversationId: state.pathParameters['id'])),
          GoRoute(
              path: '/history',
              builder: (_, __) => const _HistoryStub()),
          GoRoute(
              path: '/settings',
              builder: (_, __) => const _SettingsStub()),
          GoRoute(
              path: '/admin',
              builder: (_, __) => const _AdminStub()),
        ],
      ),
    ],
  );
});
