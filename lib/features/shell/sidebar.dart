import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/api/chat_api.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/providers/settings_provider.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'package:okakchat/core/providers/conversations_provider.dart';
import 'package:okakchat/features/chat/chat_provider.dart';

// ── Sidebar ───────────────────────────────────────────────────────────────

class AppSidebar extends ConsumerStatefulWidget {
  const AppSidebar({
    super.key,
    required this.currentLocation,
    required this.isAdmin,
  });
  final String currentLocation;
  final bool isAdmin;

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final convs = ref.watch(conversationsProvider);

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
                // ── Logo + toggle ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 8, 10),
                  child: Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.blue700,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.blue500.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.blue500.withValues(alpha: 0.25),
                              blurRadius: 10,
                              spreadRadius: -2)
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 9),
                    Text('OKAK Chat',
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textHigh,
                            letterSpacing: -0.3)),
                    const Spacer(),
                    // Collapse sidebar
                    _IconBtn(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Collapse sidebar',
                      onTap: () => ref
                          .read(settingsProvider.notifier)
                          .setSidebarOpen(false),
                    ),
                  ]),
                ),

                // ── Mode buttons ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(children: [
                    Expanded(
                      child: _ModeBtn(
                        label: 'Chat',
                        icon: Icons.chat_bubble_outline_rounded,
                        selectedIcon: Icons.chat_bubble_rounded,
                        route: '/chat',
                        current: widget.currentLocation,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ModeBtn(
                        label: 'Code',
                        icon: Icons.code_rounded,
                        route: '/code',
                        current: widget.currentLocation,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),

                // ── New chat button ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _NewChatButton(
                    onPressed: () {
                      final isCode =
                          widget.currentLocation.startsWith('/code');
                      if (isCode) {
                        ref.read(codeProvider.notifier).newChat();
                      } else {
                        ref.read(chatProvider.notifier).newChat();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // ── Search / filter ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: AppTheme.blue500.withValues(alpha: 0.12)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) =>
                          setState(() => _filter = v.toLowerCase()),
                      style: GoogleFonts.sora(
                          fontSize: 12, color: AppTheme.textHigh),
                      cursorColor: AppTheme.blue400,
                      decoration: InputDecoration(
                        hintText: 'Search chats…',
                        hintStyle: GoogleFonts.sora(
                            fontSize: 12, color: AppTheme.textLow),
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 14, color: AppTheme.textMid),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 28),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // ── Chat list ─────────────────────────────────────────
                Expanded(
                  child: convs.when(
                    loading: () => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.blue400),
                      ),
                    ),
                    error: (_, __) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Could not load chats',
                          style: GoogleFonts.sora(
                              fontSize: 11, color: AppTheme.textLow)),
                    ),
                    data: (items) {
                      final isCodeMode =
                          widget.currentLocation.startsWith('/code');
                      final filtered = items.where((c) {
                        final mode = c['mode'] as String? ?? 'chat';
                        if (isCodeMode && mode != 'coding') return false;
                        if (!isCodeMode && mode == 'coding') return false;
                        if (_filter.isEmpty) return true;
                        return (c['title'] as String)
                            .toLowerCase()
                            .contains(_filter);
                      }).toList();
                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            _filter.isEmpty
                                ? 'No chats yet'
                                : 'No results',
                            style: GoogleFonts.sora(
                                fontSize: 11, color: AppTheme.textLow),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _ConvItem(
                          conv: filtered[i],
                          currentLocation: widget.currentLocation,
                          onDeleted: () =>
                              ref.invalidate(conversationsProvider),
                        ),
                      );
                    },
                  ),
                ),

                // ── Bottom nav ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                      height: 1,
                      color: AppTheme.blue500.withValues(alpha: 0.1)),
                ),
                _BottomNavItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                  label: 'Settings',
                  route: '/settings',
                  current: widget.currentLocation,
                ),
                if (widget.isAdmin)
                  _BottomNavItem(
                    icon: Icons.shield_outlined,
                    selectedIcon: Icons.shield_rounded,
                    label: 'Admin',
                    route: '/admin',
                    current: widget.currentLocation,
                  ),

                // ── Profile button ────────────────────────────────────
                _ProfileButton(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mode button (Chat / Code) ─────────────────────────────────────────────

class _ModeBtn extends StatefulWidget {
  const _ModeBtn({
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.route,
    required this.current,
  });
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String route;
  final String current;

  @override
  State<_ModeBtn> createState() => _ModeBtnState();
}

class _ModeBtnState extends State<_ModeBtn> {
  bool _hovered = false;

  bool get _selected => widget.route == '/chat'
      ? widget.current == '/chat' ||
          (widget.current.startsWith('/chat') &&
              !widget.current.startsWith('/chat/settings'))
      : widget.current.startsWith(widget.route);

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => context.go(widget.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _selected
                  ? AppTheme.blue500.withValues(alpha: 0.15)
                  : _hovered
                      ? AppTheme.blue500.withValues(alpha: 0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _selected
                    ? AppTheme.blue500.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selected
                      ? (widget.selectedIcon ?? widget.icon)
                      : widget.icon,
                  size: 13,
                  color: _selected
                      ? AppTheme.blue400
                      : AppTheme.textMid,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: _selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _selected
                          ? AppTheme.blue300
                          : AppTheme.textMid),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── New chat button ───────────────────────────────────────────────────────

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
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 34,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.blue500.withValues(alpha: 0.18)
                  : AppTheme.blue500.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.blue500
                      .withValues(alpha: _hovered ? 0.35 : 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded,
                    size: 15, color: AppTheme.blue400),
                const SizedBox(width: 5),
                Text('New chat',
                    style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.blue400)),
              ],
            ),
          ),
        ),
      );
}

// ── Conversation item ─────────────────────────────────────────────────────

class _ConvItem extends ConsumerStatefulWidget {
  const _ConvItem({
    required this.conv,
    required this.currentLocation,
    required this.onDeleted,
  });
  final Map<String, dynamic> conv;
  final String currentLocation;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ConvItem> createState() => _ConvItemState();
}

class _ConvItemState extends ConsumerState<_ConvItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final id = widget.conv['id'] as String;
    final title = widget.conv['title'] as String? ?? 'Untitled';
    final mode = widget.conv['mode'] as String? ?? 'chat';
    final isActive = widget.currentLocation == '/chat/$id';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          if (mode == 'coding') {
            context.go('/code');
            ref.read(codeProvider.notifier).loadConversation(id);
          } else {
            context.go('/chat/$id');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.blue500.withValues(alpha: 0.14)
                : _hovered
                    ? AppTheme.blue500.withValues(alpha: 0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isActive
                  ? AppTheme.blue500.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: Row(children: [
            Icon(
              mode == 'coding'
                  ? Icons.code_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 12,
              color: isActive ? AppTheme.blue400 : AppTheme.textLow,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(
                    fontSize: 12,
                    color: isActive
                        ? AppTheme.textHigh
                        : AppTheme.textMid,
                    fontWeight: isActive
                        ? FontWeight.w500
                        : FontWeight.w400),
              ),
            ),
            if (_hovered)
              GestureDetector(
                onTap: () async {
                  await ChatApi(ref.read(dioProvider))
                      .deleteConversation(id);
                  widget.onDeleted();
                },
                child: Icon(Icons.close_rounded,
                    size: 12, color: AppTheme.textLow),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Bottom nav item ───────────────────────────────────────────────────────

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.route,
    required this.current,
  });
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final String route;
  final String current;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.current.startsWith(widget.route);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => context.go(widget.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.blue500.withValues(alpha: 0.12)
                  : _hovered
                      ? AppTheme.blue500.withValues(alpha: 0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(children: [
              Icon(
                selected
                    ? (widget.selectedIcon ?? widget.icon)
                    : widget.icon,
                size: 15,
                color: selected
                    ? AppTheme.blue400
                    : AppTheme.textMid,
              ),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected
                          ? AppTheme.blue300
                          : AppTheme.textMid)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Profile popup button ──────────────────────────────────────────────────

class _ProfileButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ProfileButton> createState() => _ProfileButtonState();
}

class _ProfileButtonState extends ConsumerState<_ProfileButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => _showProfilePopup(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.blue500.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(children: [
              // Avatar
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.blue900,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.blue500.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    user.email.isNotEmpty
                        ? user.email[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.blue300),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.displayName.isNotEmpty
                          ? user.displayName
                          : user.email.split('@').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textHigh),
                    ),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                          fontSize: 10, color: AppTheme.textLow),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz_rounded,
                  size: 15, color: AppTheme.textMid),
            ]),
          ),
        ),
      ),
    );
  }

  void _showProfilePopup(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => _ProfilePopupDialog(
        anchorOffset: offset,
        anchorHeight: box.size.height,
      ),
    );
  }
}

// ── Profile popup dialog ──────────────────────────────────────────────────

class _ProfilePopupDialog extends ConsumerWidget {
  const _ProfilePopupDialog({
    required this.anchorOffset,
    required this.anchorHeight,
  });
  final Offset anchorOffset;
  final double anchorHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final lang = ref.watch(settingsProvider).language;

    return Stack(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(color: Colors.transparent),
      ),
      Positioned(
        left: 14,
        bottom: MediaQuery.of(context).size.height -
            anchorOffset.dy +
            8,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 224,
                decoration: BoxDecoration(
                  color: AppTheme.surface2.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.blue500.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User info
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.blue900,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.blue500
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(
                              user?.email.isNotEmpty == true
                                  ? user!.email[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.sora(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.blue300),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName.isNotEmpty == true
                                    ? user!.displayName
                                    : user?.email.split('@').first ??
                                        '',
                                style: GoogleFonts.sora(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textHigh),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user?.email ?? '',
                                style: GoogleFonts.sora(
                                    fontSize: 11,
                                    color: AppTheme.textMid),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                    _Divider(),
                    // Language switcher
                    _PopupItem(
                      icon: Icons.language_rounded,
                      label: 'Language',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: ['en', 'ru'].map((l) {
                          final sel = lang == l;
                          return GestureDetector(
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setLanguage(l),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 130),
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.blue500
                                        .withValues(alpha: 0.25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: sel
                                      ? AppTheme.blue500
                                          .withValues(alpha: 0.4)
                                      : AppTheme.blue500
                                          .withValues(alpha: 0.1),
                                ),
                              ),
                              child: Text(
                                l.toUpperCase(),
                                style: GoogleFonts.sora(
                                    fontSize: 10,
                                    color: sel
                                        ? AppTheme.blue300
                                        : AppTheme.textMid,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w400),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      onTap: null,
                    ),
                    // Settings
                    _PopupItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/settings');
                      },
                    ),
                    _Divider(),
                    // Sign out
                    _PopupItem(
                      icon: Icons.logout_rounded,
                      label: 'Sign out',
                      danger: true,
                      onTap: () async {
                        Navigator.pop(context);
                        await ref
                            .read(authProvider.notifier)
                            .logout();
                        if (context.mounted) {
                          context.go('/auth/login');
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: AppTheme.blue500.withValues(alpha: 0.1),
      );
}

class _PopupItem extends StatefulWidget {
  const _PopupItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  State<_PopupItem> createState() => _PopupItemState();
}

class _PopupItemState extends State<_PopupItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger
        ? const Color(0xFFEF4444)
        : AppTheme.textMid;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null
                ? (widget.danger
                    ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                    : AppTheme.blue500.withValues(alpha: 0.07))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(children: [
            Icon(widget.icon, size: 15, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.label,
                  style: GoogleFonts.sora(
                      fontSize: 13, color: color)),
            ),
            if (widget.trailing != null) widget.trailing!,
          ]),
        ),
      ),
    );
  }
}

// ── Small icon button ─────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit:  (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppTheme.blue500.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(widget.icon,
                  size: 16, color: AppTheme.textMid),
            ),
          ),
        ),
      );
}
