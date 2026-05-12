import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar(
      {super.key, required this.currentLocation, required this.isAdmin});
  final String currentLocation;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'OKAK Chat',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Chat'),
            onPressed: () => context.go('/chat'),
          ).withPadding(const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
          const Divider(),
          _NavItem(
              icon: Icons.chat_outlined,
              selectedIcon: Icons.chat,
              label: 'Chat',
              route: '/chat',
              current: currentLocation),
          _NavItem(
              icon: Icons.history,
              label: 'History',
              route: '/history',
              current: currentLocation),
          _NavItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: 'Settings',
              route: '/settings',
              current: currentLocation),
          if (isAdmin)
            _NavItem(
                icon: Icons.admin_panel_settings_outlined,
                selectedIcon: Icons.admin_panel_settings,
                label: 'Admin',
                route: '/admin',
                current: currentLocation),
          const Spacer(),
        ],
      ),
    );
  }
}

extension on Widget {
  Widget withPadding(EdgeInsets padding) =>
      Padding(padding: padding, child: this);
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.route,
    required this.current,
  });
  final IconData icon;
  final IconData? selectedIcon;
  final String label, route, current;

  @override
  Widget build(BuildContext context) {
    final selected = current.startsWith(route) && route != '/chat'
        ? true
        : current == route || (route == '/chat' && current.startsWith('/chat'));
    return ListTile(
      leading: Icon(
        selected ? (selectedIcon ?? icon) : icon,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
      selected: selected,
      selectedTileColor:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () => context.go(route),
    );
  }
}
