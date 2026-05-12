import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/theme/app_theme.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar(
      {super.key, required this.currentLocation, required this.isAdmin});
  final String currentLocation;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;

    return SizedBox(
      width: 228,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bg.withValues(alpha: 0.85),
              border: Border(
                right: BorderSide(
                    color: AppTheme.blue500.withValues(alpha: 0.12)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                  child: Row(children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: AppTheme.blue700,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.blue500.withValues(alpha: 0.4)),
                        boxShadow: [BoxShadow(
                            color: AppTheme.blue500.withValues(alpha: 0.25),
                            blurRadius: 12, spreadRadius: -2)],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text('OKAK Chat', style: GoogleFonts.sora(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppTheme.textHigh, letterSpacing: -0.3)),
                  ]),
                ),

                // New chat
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _NewChatButton(onPressed: () => context.go('/chat')),
                ),

                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(height: 1,
                      color: AppTheme.blue500.withValues(alpha: 0.1)),
                ),
                const SizedBox(height: 6),

                // Nav
                _NavItem(icon: Icons.chat_bubble_outline_rounded,
                    selectedIcon: Icons.chat_bubble_rounded,
                    label: 'Chat', route: '/chat', current: currentLocation),
                _NavItem(icon: Icons.history_rounded, label: 'History',
                    route: '/history', current: currentLocation),
                _NavItem(icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings_rounded,
                    label: 'Settings', route: '/settings',
                    current: currentLocation),
                if (isAdmin)
                  _NavItem(icon: Icons.shield_outlined,
                      selectedIcon: Icons.shield_rounded,
                      label: 'Admin', route: '/admin',
                      current: currentLocation),

                const Spacer(),

                // User footer
                if (user != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(height: 1,
                        color: AppTheme.blue500.withValues(alpha: 0.1)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.blue900, shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.blue500.withValues(alpha: 0.3)),
                        ),
                        child: Center(child: Text(
                          user.email.isNotEmpty
                              ? user.email[0].toUpperCase() : '?',
                          style: GoogleFonts.sora(fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.blue300),
                        )),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(user.email, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                              fontSize: 11, color: AppTheme.textMid))),
                    ]),
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewChatButton extends StatefulWidget {
  const _NewChatButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}
class _NewChatButtonState extends State<_NewChatButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 38,
      decoration: BoxDecoration(
        color: _hovered
            ? AppTheme.blue500.withValues(alpha: 0.15)
            : AppTheme.blue500.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.blue500
            .withValues(alpha: _hovered ? 0.35 : 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onPressed,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_rounded, size: 16, color: AppTheme.blue400),
          const SizedBox(width: 6),
          Text('New Chat', style: GoogleFonts.sora(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppTheme.blue400)),
        ]),
      ),
    ),
  );
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.icon, this.selectedIcon,
      required this.label, required this.route, required this.current});
  final IconData icon;
  final IconData? selectedIcon;
  final String label, route, current;
  @override
  State<_NavItem> createState() => _NavItemState();
}
class _NavItemState extends State<_NavItem> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final selected = widget.route == '/chat'
        ? widget.current == widget.route || widget.current.startsWith('/chat')
        : widget.current.startsWith(widget.route);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.blue500.withValues(alpha: 0.14)
                : _hovered
                    ? AppTheme.blue500.withValues(alpha: 0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected
                ? AppTheme.blue500.withValues(alpha: 0.28)
                : Colors.transparent),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go(widget.route),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(children: [
                Icon(selected ? (widget.selectedIcon ?? widget.icon) : widget.icon,
                    size: 17,
                    color: selected ? AppTheme.blue400 : AppTheme.textMid),
                const SizedBox(width: 10),
                Text(widget.label, style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppTheme.blue300 : AppTheme.textMid)),
                if (selected) ...[
                  const Spacer(),
                  Container(width: 4, height: 4, decoration: BoxDecoration(
                      color: AppTheme.blue400, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: AppTheme.blue400.withValues(alpha: 0.6),
                          blurRadius: 6)])),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
