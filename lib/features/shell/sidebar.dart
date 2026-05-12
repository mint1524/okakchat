import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/auth/auth_provider.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar(
      {super.key, required this.currentLocation, required this.isAdmin});
  final String currentLocation;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs   = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).valueOrNull;

    return SizedBox(
      width: 240,
      child: Material(
        color: cs.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Logo ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'OKAK Chat',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ]),
            ),

            // ── New chat ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Chat'),
                onPressed: () => context.go('/chat'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),

            // ── Nav ───────────────────────────────────────────────────
            _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                selectedIcon: Icons.chat_bubble_rounded,
                label: 'Chat',
                route: '/chat',
                current: currentLocation),
            _NavItem(
                icon: Icons.history_rounded,
                label: 'History',
                route: '/history',
                current: currentLocation),
            _NavItem(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                label: 'Settings',
                route: '/settings',
                current: currentLocation),
            if (isAdmin)
              _NavItem(
                  icon: Icons.admin_panel_settings_outlined,
                  selectedIcon: Icons.admin_panel_settings_rounded,
                  label: 'Admin',
                  route: '/admin',
                  current: currentLocation),

            const Spacer(),

            // ── User footer ───────────────────────────────────────────
            if (user != null) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      user.email.isNotEmpty
                          ? user.email[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.7)),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
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
    final cs = Theme.of(context).colorScheme;
    final selected = route == '/chat'
        ? current == route || current.startsWith('/chat')
        : current.startsWith(route);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(route),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(children: [
              Icon(
                selected ? (selectedIcon ?? icon) : icon,
                size: 18,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
