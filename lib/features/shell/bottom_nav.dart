import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav(
      {super.key, required this.currentLocation, required this.isAdmin});
  final String currentLocation;
  final bool isAdmin;

  int _currentIndex() {
    if (currentLocation.startsWith('/code')) return 1;
    if (currentLocation.startsWith('/history')) return 2;
    if (currentLocation.startsWith('/settings')) return 3;
    if (currentLocation.startsWith('/admin')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _currentIndex(),
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            context.go('/chat');
          case 1:
            context.go('/code');
          case 2:
            context.go('/history');
          case 3:
            context.go('/settings');
          case 4:
            context.go('/admin');
        }
      },
      destinations: [
        const NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat'),
        const NavigationDestination(
            icon: Icon(Icons.code_outlined),
            selectedIcon: Icon(Icons.code),
            label: 'Code'),
        const NavigationDestination(
            icon: Icon(Icons.history), label: 'History'),
        const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings'),
        if (isAdmin)
          const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'Admin'),
      ],
    );
  }
}
