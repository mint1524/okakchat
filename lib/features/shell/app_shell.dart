import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/debug/app_logger.dart';
import 'package:okakchat/core/providers/settings_provider.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'package:okakchat/core/theme/platform_utils.dart';
import 'package:window_manager/window_manager.dart';
import 'sidebar.dart';
import 'bottom_nav.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user    = ref.watch(authProvider).valueOrNull;
    final isAdmin = user?.isAdmin ?? false;
    final location = GoRouterState.of(context).matchedLocation;
    final settings = ref.watch(settingsProvider);
    final sidebarOpen = settings.sidebarOpen;

    Widget sidebarSide;
    if (sidebarOpen) {
      sidebarSide = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSidebar(currentLocation: location, isAdmin: isAdmin),
          Container(width: 1,
              color: AppTheme.blue500.withValues(alpha: 0.1)),
        ],
      );
    } else {
      sidebarSide = const _CollapsedSidebarAffordance();
    }

    if (PlatformUtils.isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Column(
          children: [
            if (!kIsWeb) const _CustomTitleBar(),
            Expanded(
              child: Row(
                children: [
                  sidebarSide,
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (PlatformUtils.isWeb) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Row(
          children: [
            sidebarSide,
            Expanded(child: child),
          ],
        ),
      );
    }

    if (PlatformUtils.isIOS) {
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

    // Android
    return Scaffold(
      backgroundColor: AppTheme.bg,
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
    const routes = ['/chat', '/history', '/settings', '/admin'];
    final route = i < routes.length ? routes[i] : '?';
    AppLogger.tap('Tab[$i] → $route');
    switch (i) {
      case 0: context.go('/chat');
      case 1: context.go('/history');
      case 2: context.go('/settings');
      case 3: if (isAdmin) context.go('/admin');
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

// ── Custom title bar ──────────────────────────────────────────────────────

class _CustomTitleBar extends StatefulWidget {
  const _CustomTitleBar();
  @override
  State<_CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<_CustomTitleBar>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _init();
  }

  Future<void> _init() async {
    _isMaximized = await windowManager.isMaximized();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);
  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: AppTheme.bg,
      child: Row(
        children: [
          // Drag region fills most of the bar
          Expanded(
            child: GestureDetector(
              onDoubleTap: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: DragToMoveArea(
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.blue700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            size: 10, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'OKAK Chat',
                        style: TextStyle(
                          color: AppTheme.textMid,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Window control buttons
          _WinButton(
            icon: Icons.remove_rounded,
            tooltip: 'Minimise',
            onPressed: () => windowManager.minimize(),
          ),
          _WinButton(
            icon: _isMaximized
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            tooltip: _isMaximized ? 'Restore' : 'Maximise',
            onPressed: () async {
              if (_isMaximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WinButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            isClose: true,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class _WinButton extends StatefulWidget {
  const _WinButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 46,
            height: 38,
            color: _hovered
                ? (widget.isClose
                    ? const Color(0xFFE81123)
                    : AppTheme.blue500.withValues(alpha: 0.12))
                : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 16,
              color: _hovered && widget.isClose
                  ? Colors.white
                  : AppTheme.textMid,
            ),
            ),
          ),
        ),
      );
    }
  }

// ── Collapsed sidebar affordance ────────────────────────────────────────────

class _CollapsedSidebarAffordance extends ConsumerWidget {
  const _CollapsedSidebarAffordance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(settingsProvider.notifier).setSidebarOpen(true),
      child: Container(
        width: 40,
        decoration: BoxDecoration(
          color: AppTheme.bg,
          border: Border(
            right: BorderSide(
                color: AppTheme.blue500.withValues(alpha: 0.12)),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
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
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 14),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textMid, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
