import 'package:flutter/material.dart';
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

// ── Auth-change notifier for GoRouter.refreshListenable ──────────────────
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AsyncValue<dynamic>>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }
}

/// Router created ONCE and refreshed via [_AuthChangeNotifier].
/// Using ref.watch inside Provider recreates GoRouter on every auth change —
/// that resets navigation. This approach avoids it.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);

  final router = GoRouter(
    initialLocation: '/chat',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState  = ref.read(authProvider);
      final isLoading  = authState.isLoading;
      final user       = authState.valueOrNull;
      final isAuth     = user != null;
      final loc        = state.matchedLocation;
      final isAuthRoute = loc.startsWith('/auth');
      final isAdmin    = user?.isAdmin ?? false;

      // Still loading stored token — don't redirect yet
      if (isLoading) return null;

      // Not logged in → send to login (unless already on auth route)
      if (!isAuth && !isAuthRoute) return '/auth/login';

      // Logged in but on auth screen → send to chat
      if (isAuth && isAuthRoute) return '/chat';

      // Non-admin trying to access admin panel
      if (loc.startsWith('/admin') && !isAdmin) return '/chat';

      return null;
    },
    routes: [
      GoRoute(path: '/auth/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/auth/verify',
          builder: (_, state) => VerifyScreen(
                userId: state.uri.queryParameters['userId'] ?? '',
                email:  state.uri.queryParameters['email']  ?? '',
              )),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/chat',     builder: (_, __) => const ChatScreen()),
          GoRoute(
              path: '/chat/:id',
              builder: (_, state) =>
                  ChatScreen(conversationId: state.pathParameters['id'])),
          GoRoute(path: '/history',  builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/admin',    builder: (_, __) => const AdminShell()),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});
