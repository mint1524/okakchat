import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:okakchat/core/auth/auth_provider.dart';

// Stub screens — will be replaced in later tasks
class _LoginStub extends StatelessWidget {
  const _LoginStub();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Login')));
}
class _RegisterStub extends StatelessWidget {
  const _RegisterStub();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Register')));
}
class _VerifyStub extends StatelessWidget {
  const _VerifyStub({required this.userId, required this.email});
  final String userId, email;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Verify: $email')));
}
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
class _ShellStub extends StatelessWidget {
  const _ShellStub({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
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
          builder: (_, __) => const _LoginStub()),
      GoRoute(
          path: '/auth/register',
          builder: (_, __) => const _RegisterStub()),
      GoRoute(
          path: '/auth/verify',
          builder: (_, state) => _VerifyStub(
                userId: state.uri.queryParameters['userId'] ?? '',
                email: state.uri.queryParameters['email'] ?? '',
              )),
      ShellRoute(
        builder: (context, state, child) => _ShellStub(child: child),
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
