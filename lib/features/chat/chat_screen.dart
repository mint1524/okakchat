import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'package:okakchat/core/widgets/animated_background.dart';
import 'package:okakchat/core/widgets/notification_banner.dart';
import 'chat_provider.dart';
import 'message_bubble.dart';
import 'chat_input.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.conversationId});
  final String? conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollCtrl = ScrollController();
  bool _showScrollBtn = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(chatProvider.notifier).loadModels();
        if (widget.conversationId != null) {
          await ref
              .read(chatProvider.notifier)
              .loadConversation(widget.conversationId!);
        }
      } catch (_) {}
    });
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversationId != oldWidget.conversationId) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (widget.conversationId != null) {
          await ref
              .read(chatProvider.notifier)
              .loadConversation(widget.conversationId!);
        } else {
          ref.read(chatProvider.notifier).newChat();
        }
      });
    }
  }

  void _onScroll() {
    final show = _scrollCtrl.hasClients &&
        _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset > 120;
    if (show != _showScrollBtn) setState(() => _showScrollBtn = show);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    ref.listen(chatProvider, (prev, next) {
      if (next.messages.length != prev?.messages.length) {
        _scrollToBottom();
      }
    });

    return NotificationBannerStack(
      child: Stack(children: [
        const Positioned.fill(
            child: AnimatedBackground(particleCount: 18)),
        Column(children: [
          _ChatTopBar(),
          Container(height: 1,
              color: AppTheme.blue500.withValues(alpha: 0.1)),
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const _ConversationSkeleton()
                : state.messages.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding:
                            const EdgeInsets.only(top: 12, bottom: 12),
                        itemCount: state.messages.length,
                        itemBuilder: (_, i) => MessageBubble(
                          message: state.messages[i],
                          provider: chatProvider,
                          isLast: i == state.messages.length - 1 &&
                              state.messages[i].role == 'assistant',
                        ),
                      ),
          ),
          _GlassInputArea(onSend: _scrollToBottom),
        ]),
        // Scroll to bottom btn
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          bottom: _showScrollBtn ? 90 : -60,
          right: 24,
          child: _ScrollToBottomBtn(onTap: _scrollToBottom),
        ),
      ]),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────

class _ChatTopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: AppTheme.bg.withValues(alpha: 0.7)),
          child: Row(children: [
            const Icon(Icons.chat_bubble_rounded,
                size: 14, color: AppTheme.blue400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.conversationId != null &&
                        state.messages.isNotEmpty
                    ? state.messages.first.content.length > 40
                        ? '${state.messages.first.content.substring(0, 40)}…'
                        : state.messages.first.content
                    : 'Chat',
                style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textHigh),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // New chat
            _TopBarIconBtn(
              icon: Icons.add_rounded,
              tooltip: 'New chat',
              onTap: () =>
                  ref.read(chatProvider.notifier).newChat(),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TopBarIconBtn extends StatefulWidget {
  const _TopBarIconBtn(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_TopBarIconBtn> createState() => _TopBarIconBtnState();
}

class _TopBarIconBtnState extends State<_TopBarIconBtn> {
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
              duration: const Duration(milliseconds: 130),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppTheme.blue500.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, size: 17, color: AppTheme.textMid),
            ),
          ),
        ),
      );
}

// ── Glass input area ──────────────────────────────────────────────────────

class _GlassInputArea extends StatelessWidget {
  const _GlassInputArea({required this.onSend});
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bg.withValues(alpha: 0.75),
              border: Border(
                top: BorderSide(
                    color: AppTheme.blue500.withValues(alpha: 0.1)),
              ),
            ),
            child: ChatInput(
              onSend: onSend,
              provider: chatProvider,
            ),
          ),
        ),
      );
}

// ── Scroll to bottom ──────────────────────────────────────────────────────

class _ScrollToBottomBtn extends StatelessWidget {
  const _ScrollToBottomBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.blue700,
            shape: BoxShape.circle,
            border: Border.all(
                color: AppTheme.blue500.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.blue500.withValues(alpha: 0.3),
                  blurRadius: 14,
                  spreadRadius: -2)
            ],
          ),
          child: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white, size: 20),
        ),
      );
}

// ── Skeleton loader ───────────────────────────────────────────────────────

class _ConversationSkeleton extends StatefulWidget {
  const _ConversationSkeleton();
  @override
  State<_ConversationSkeleton> createState() => _ConversationSkeletonState();
}

class _ConversationSkeletonState extends State<_ConversationSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _shimmer = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _shimmer,
        builder: (_, __) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SkeletonBubble(
                width: 0.55,
                align: Alignment.centerRight,
                shimmer: _shimmer.value),
            const SizedBox(height: 12),
            _SkeletonBubble(
                width: 0.8,
                align: Alignment.centerLeft,
                shimmer: _shimmer.value,
                lines: 3),
            const SizedBox(height: 12),
            _SkeletonBubble(
                width: 0.45,
                align: Alignment.centerRight,
                shimmer: _shimmer.value),
            const SizedBox(height: 12),
            _SkeletonBubble(
                width: 0.85,
                align: Alignment.centerLeft,
                shimmer: _shimmer.value,
                lines: 4),
          ],
        ),
      );
}

class _SkeletonBubble extends StatelessWidget {
  const _SkeletonBubble({
    required this.width,
    required this.align,
    required this.shimmer,
    this.lines = 2,
  });
  final double width;
  final Alignment align;
  final double shimmer;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final isRight = align == Alignment.centerRight;
    final color = Color.lerp(
      isRight ? AppTheme.blue900 : AppTheme.surface2,
      isRight ? AppTheme.blue700 : AppTheme.surface3,
      (shimmer * 2 - (isRight ? 0.3 : 0.0)).clamp(0.0, 1.0),
    )!;
    return Align(
      alignment: align,
      child: FractionallySizedBox(
        widthFactor: width,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              lines,
              (i) => Padding(
                padding:
                    EdgeInsets.only(bottom: i < lines - 1 ? 6 : 0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  const _EmptyState();
  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.blue500
                        .withValues(alpha: 0.1 + 0.14 * _pulse.value),
                    blurRadius: 32 + 24 * _pulse.value,
                  )
                ],
              ),
              child: child,
            ),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.blue900,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.blue500.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 32, color: AppTheme.blue400),
            ),
          ),
          const SizedBox(height: 22),
          Text('What can I help with?',
              style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textHigh,
                  letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text('Choose a model and start typing.',
              style: GoogleFonts.sora(
                  fontSize: 13, color: AppTheme.textMid)),
        ]),
      );
}
