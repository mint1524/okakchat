import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/debug/app_logger.dart';
import 'package:okakchat/features/auth/login_screen.dart';
import 'package:okakchat/features/auth/register_screen.dart';
import 'package:okakchat/features/auth/verify_screen.dart';
import 'package:okakchat/features/shell/app_shell.dart';
import 'package:okakchat/features/chat/chat_screen.dart';
import 'package:okakchat/features/chat/code_screen.dart';
import 'package:okakchat/features/history/history_screen.dart';
import 'package:okakchat/features/settings/settings_screen.dart';
import 'package:okakchat/features/admin/admin_shell.dart';

Page<void> _noAnimPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, __, ___, c) => c,
  );
}

// ── Debug navigation observer ─────────────────────────────────────────────
class _DebugNavObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    if (!kDebugMode) return;
    final name = route.settings.name ?? route.runtimeType.toString();
    final prev = previousRoute?.settings.name ?? '—';
    AppLogger.nav('push  $prev → $name');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (!kDebugMode) return;
    final name = route.settings.name ?? route.runtimeType.toString();
    final prev = previousRoute?.settings.name ?? '—';
    AppLogger.nav('pop   $name → $prev');
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (!kDebugMode) return;
    final n = newRoute?.settings.name ?? '?';
    final o = oldRoute?.settings.name ?? '?';
    AppLogger.nav('replace $o → $n');
  }
}

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
    observers: kDebugMode ? [_DebugNavObserver()] : [],
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
      GoRoute(path: '/auth/login',    pageBuilder: (_, state) => _noAnimPage(state, const LoginScreen())),
      GoRoute(path: '/auth/register', pageBuilder: (_, state) => _noAnimPage(state, const RegisterScreen())),
      GoRoute(
          path: '/auth/verify',
          pageBuilder: (_, state) => _noAnimPage(state, VerifyScreen(
                userId: state.uri.queryParameters['userId'] ?? '',
                email:  state.uri.queryParameters['email']  ?? '',
              ))),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/chat',     pageBuilder: (_, state) => _noAnimPage(state, const ChatScreen())),
          GoRoute(
              path: '/chat/:id',
              pageBuilder: (_, state) => _noAnimPage(state,
                  ChatScreen(conversationId: state.pathParameters['id']))),
          GoRoute(path: '/code',     pageBuilder: (_, state) => _noAnimPage(state, const CodeScreen())),
          GoRoute(path: '/history',  pageBuilder: (_, state) => _noAnimPage(state, const HistoryScreen())),
          GoRoute(path: '/settings', pageBuilder: (_, state) => _noAnimPage(state, const SettingsScreen())),
          GoRoute(path: '/admin',    pageBuilder: (_, state) => _noAnimPage(state, const AdminShell())),
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
