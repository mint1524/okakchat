import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/notifications_provider.dart';

class NotificationBannerStack extends ConsumerWidget {
  const NotificationBannerStack({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);

    return Stack(children: [
      child,
      if (notifs.isNotEmpty)
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Column(
            children: notifs
                .map((n) => _Banner(
                      key: ValueKey(n.id),
                      notif: n,
                      onDismiss: () =>
                          ref.read(notificationsProvider.notifier).dismiss(n.id),
                    ))
                .toList(),
          ),
        ),
    ]);
  }
}

class _Banner extends StatefulWidget {
  const _Banner({super.key, required this.notif, required this.onDismiss});
  final AppNotification notif;
  final VoidCallback onDismiss;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<double>(begin: -16, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _borderColor => switch (widget.notif.type) {
        NotifType.error   => const Color(0xFFEF4444).withValues(alpha: 0.5),
        NotifType.warning => const Color(0xFFF59E0B).withValues(alpha: 0.5),
        NotifType.success => const Color(0xFF22C55E).withValues(alpha: 0.5),
        NotifType.info    => AppTheme.blue500.withValues(alpha: 0.4),
      };

  Color get _iconColor => switch (widget.notif.type) {
        NotifType.error   => const Color(0xFFEF4444),
        NotifType.warning => const Color(0xFFF59E0B),
        NotifType.success => const Color(0xFF22C55E),
        NotifType.info    => AppTheme.blue400,
      };

  IconData get _icon => switch (widget.notif.type) {
        NotifType.error   => Icons.error_outline_rounded,
        NotifType.warning => Icons.warning_amber_rounded,
        NotifType.success => Icons.check_circle_outline_rounded,
        NotifType.info    => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _slide.value),
        child: Opacity(opacity: _fade.value, child: child),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Row(children: [
                    Icon(_icon, size: 18, color: _iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.notif.message,
                        style: GoogleFonts.sora(
                            fontSize: 13, color: AppTheme.textHigh),
                      ),
                    ),
                    if (widget.notif.action != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          widget.notif.action!();
                          widget.onDismiss();
                        },
                        child: Text(
                          widget.notif.actionLabel ?? 'Retry',
                          style: GoogleFonts.sora(
                              fontSize: 12,
                              color: AppTheme.blue400,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Icon(Icons.close_rounded,
                          size: 16, color: AppTheme.textMid),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
