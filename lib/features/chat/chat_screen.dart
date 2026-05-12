import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'package:okakchat/core/widgets/animated_background.dart';
import 'chat_provider.dart';
import 'message_bubble.dart';
import 'chat_input.dart';
import 'model_selector.dart';
import 'model_settings_sheet.dart';
import 'code_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.conversationId,
    this.agentMode = false,
    this.workspacePath,
  });
  final String? conversationId;
  final bool agentMode;
  final String? workspacePath;

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
          duration: const Duration(milliseconds: 300),
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

    // Redirect to code mode if selected
    if (state.mode == 'coding') {
      return const CodeScreen();
    }

    return Stack(
      children: [
        // Subtle animated background
        const Positioned.fill(
          child: AnimatedBackground(particleCount: 18),
        ),

        // Main layout
        Column(children: [
          _TopBar(state: state),
          // Glass divider
          Container(height: 1,
              color: AppTheme.blue500.withValues(alpha: 0.1)),
          // Messages
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const _ConversationSkeleton()
                : state.messages.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        itemCount: state.messages.length,
                        itemBuilder: (_, i) =>
                            MessageBubble(message: state.messages[i]),
                      ),
          ),
          // Glass input
          _GlassInputArea(onSend: _scrollToBottom),
        ]),

        // Scroll to bottom button
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          bottom: _showScrollBtn ? 90 : -60,
          right: 24,
          child: _ScrollToBottomBtn(onTap: _scrollToBottom),
        ),
      ],
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state});
  final ChatState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.bg.withValues(alpha: 0.7),
          ),
          child: Row(children: [
            Expanded(
              child: ModelSelector(
                selectedModel: state.selectedModel,
                models: state.models,
                onSelected: (m) =>
                    ref.read(chatProvider.notifier).selectModel(m),
              ),
            ),
            const SizedBox(width: 8),
            _ModeChip(
              label: 'Chat',
              icon: Icons.chat_bubble_outline_rounded,
              selected: state.mode == 'chat',
              onTap: () => ref.read(chatProvider.notifier).setMode('chat'),
            ),
            const SizedBox(width: 4),
            _ModeChip(
              label: 'Code',
              icon: Icons.code_rounded,
              selected: state.mode == 'coding',
              onTap: () => ref.read(chatProvider.notifier).setMode('coding'),
            ),
            const SizedBox(width: 4),
            _TopBarBtn(
              icon: Icons.tune_rounded,
              tooltip: 'Model settings',
              badge: state.systemPrompt != null && state.systemPrompt!.isNotEmpty,
              onTap: () => ModelSettingsSheet.show(context),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ModeChip extends StatefulWidget {
  const _ModeChip({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_ModeChip> createState() => _ModeChipState();
}
class _ModeChipState extends State<_ModeChip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.selected
              ? AppTheme.blue500.withValues(alpha: 0.2)
              : _hovered
                  ? AppTheme.blue500.withValues(alpha: 0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.selected
                ? AppTheme.blue500.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, size: 14,
              color: widget.selected ? AppTheme.blue400 : AppTheme.textMid),
          const SizedBox(width: 5),
          Text(widget.label,
              style: GoogleFonts.sora(
                  fontSize: 12,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w400,
                  color: widget.selected ? AppTheme.blue300 : AppTheme.textMid)),
        ]),
      ),
    ),
  );
}

class _TopBarBtn extends StatefulWidget {
  const _TopBarBtn({
    required this.icon, required this.tooltip,
    required this.onTap, this.badge = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool badge;
  @override
  State<_TopBarBtn> createState() => _TopBarBtnState();
}
class _TopBarBtnState extends State<_TopBarBtn> {
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
          duration: const Duration(milliseconds: 140),
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.blue500.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Icon(widget.icon, size: 18, color: AppTheme.textMid),
            if (widget.badge)
              Positioned(
                right: 5, top: 5,
                child: Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: AppTheme.blue400,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: AppTheme.blue400.withValues(alpha: 0.6),
                        blurRadius: 4)],
                  ),
                ),
              ),
          ]),
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
        child: ChatInput(onSend: onSend),
      ),
    ),
  );
}

// ── Scroll to bottom button ───────────────────────────────────────────────

class _ScrollToBottomBtn extends StatelessWidget {
  const _ScrollToBottomBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppTheme.blue700,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.blue500.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(
            color: AppTheme.blue500.withValues(alpha: 0.3),
            blurRadius: 16, spreadRadius: -2)],
      ),
      child: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.white, size: 22),
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
        _SkeletonBubble(width: 0.55, align: Alignment.centerRight,
            shimmer: _shimmer.value),
        const SizedBox(height: 12),
        _SkeletonBubble(width: 0.8, align: Alignment.centerLeft,
            shimmer: _shimmer.value, lines: 3),
        const SizedBox(height: 12),
        _SkeletonBubble(width: 0.45, align: Alignment.centerRight,
            shimmer: _shimmer.value),
        const SizedBox(height: 12),
        _SkeletonBubble(width: 0.85, align: Alignment.centerLeft,
            shimmer: _shimmer.value, lines: 4),
      ],
    ),
  );
}

class _SkeletonBubble extends StatelessWidget {
  const _SkeletonBubble({
    required this.width, required this.align,
    required this.shimmer, this.lines = 2,
  });
  final double width;
  final Alignment align;
  final double shimmer;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final isRight = align == Alignment.centerRight;
    final baseColor = isRight
        ? AppTheme.blue900
        : AppTheme.surface2;
    final shimmerColor = isRight
        ? AppTheme.blue700
        : AppTheme.surface3;
    final color = Color.lerp(baseColor, shimmerColor,
        (shimmer * 2 - (isRight ? 0.3 : 0.0)).clamp(0.0, 1.0))!;

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
            children: List.generate(lines, (i) => Padding(
              padding: EdgeInsets.only(bottom: i < lines - 1 ? 6 : 0),
              child: Container(
                height: 10,
                width: i == lines - 1
                    ? double.infinity * 0.7
                    : double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            )),
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
            boxShadow: [BoxShadow(
              color: AppTheme.blue500
                  .withValues(alpha: 0.1 + 0.14 * _pulse.value),
              blurRadius: 32 + 24 * _pulse.value,
            )],
          ),
          child: child,
        ),
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppTheme.blue900,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppTheme.blue500.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 34, color: AppTheme.blue400),
        ),
      ),
      const SizedBox(height: 24),
      Text('What can I help with?',
          style: GoogleFonts.sora(
              fontSize: 20, fontWeight: FontWeight.w600,
              color: AppTheme.textHigh, letterSpacing: -0.3)),
      const SizedBox(height: 8),
      Text('Choose a model and start typing.',
          style: GoogleFonts.sora(fontSize: 14, color: AppTheme.textMid)),
    ]),
  );
}
