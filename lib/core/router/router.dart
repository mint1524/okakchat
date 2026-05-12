import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/features/auth/login_screen.dart';
import 'package:okakchat/features/auth/register_screen.dart';
import 'package:okakchat/features/auth/verify_screen.dart';
import 'package:okakchat/features/shell/app_shell.dart';
import 'package:okakchat/features/chat/chat_screen.dart';
import 'package:okakchat/features/history/history_screen.dart';
import 'package:okakchat/features/settings/settings_screen.dart';
import 'package:okakchat/features/admin/admin_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  return GoRouter(
    initialLocation: '/chat',
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final isAuthenticated = user != null;
      final isLoading = authState.isLoading;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      if (isLoading) return null;
      if (!isAuthenticated && !isAuthRoute) return '/auth/login';
      if (isAuthenticated && isAuthRoute) return '/chat';
      if (isAdminRoute && !(user?.isAdmin ?? false)) return '/chat';
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
              builder: (_, __) => const ChatScreen()),
          GoRoute(
              path: '/chat/:id',
              builder: (_, state) =>
                  ChatScreen(conversationId: state.pathParameters['id'])),
          GoRoute(
              path: '/history',
              builder: (_, __) => const HistoryScreen()),
          GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen()),
          GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminShell()),
        ],
      ),
    ],
  );
});
