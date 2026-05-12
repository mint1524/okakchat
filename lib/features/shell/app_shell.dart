import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/theme/platform_utils.dart';
import 'sidebar.dart';
import 'bottom_nav.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final isAdmin = user?.isAdmin ?? false;
    final location = GoRouterState.of(context).matchedLocation;

    if (PlatformUtils.isDesktop || PlatformUtils.isWeb) {
      return Scaffold(
        body: Row(
          children: [
            AppSidebar(currentLocation: location, isAdmin: isAdmin),
            VerticalDivider(width: 1, thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant),
            Expanded(child: child),
          ],
        ),
      );
    }

    if (PlatformUtils.isIOS) {
      // Cupertino tab bar — navigation is handled by go_router, tabs just switch routes
      return CupertinoPageScaffold(
        child: Column(
          children: [
            Expanded(child: child),
            CupertinoTabBar(
              currentIndex: _tabIndex(location),
              onTap: (i) => _onTabTap(context, i, isAdmin),
              items: _tabItems(isAdmin),
            ),
          ],
        ),
      );
    }

    // Android — Material 3 NavigationBar
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNav(
          currentLocation: location, isAdmin: isAdmin),
    );
  }

  int _tabIndex(String location) {
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/settings')) return 2;
    if (location.startsWith('/admin')) return 3;
    return 0;
  }

  void _onTabTap(BuildContext context, int i, bool isAdmin) {
    switch (i) {
      case 0:
        context.go('/chat');
      case 1:
        context.go('/history');
      case 2:
        context.go('/settings');
      case 3:
        if (isAdmin) context.go('/admin');
    }
  }

  List<BottomNavigationBarItem> _tabItems(bool isAdmin) => [
        const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble), label: 'Chat'),
        const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.clock), label: 'History'),
        const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings), label: 'Settings'),
        if (isAdmin)
          const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.shield), label: 'Admin'),
      ];
}
