import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'chat_provider.dart';

// ── Entry ─────────────────────────────────────────────────────────────────

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.provider,
    this.isLast = false,
  });
  final ChatMessage message;
  final StateNotifierProvider<ChatNotifier, ChatState> provider;
  final bool isLast;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    final isUser = widget.message.role == 'user';
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _slide = Tween<Offset>(
      begin: Offset(isUser ? 0.04 : -0.04, 0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: _BubbleContent(
            message: widget.message,
            provider: widget.provider,
            isLast: widget.isLast,
          ),
        ),
      );
}

// ── Content router ────────────────────────────────────────────────────────

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({
    required this.message,
    required this.provider,
    required this.isLast,
  });
  final ChatMessage message;
  final StateNotifierProvider<ChatNotifier, ChatState> provider;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    if (message.role == 'tool') {
      return _ToolCallBubble(message: message);
    }
    if (message.role == 'user') {
      return _UserBubble(message: message, provider: provider);
    }
    return _AssistantBubble(
        message: message, provider: provider, isLast: isLast);
  }
}

// ── Timestamp helper ──────────────────────────────────────────────────────

String _formatTime(DateTime ts) {
  final now = DateTime.now();
  final diff = now.difference(ts);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (ts.day == now.day &&
      ts.month == now.month &&
      ts.year == now.year) {
    return DateFormat('HH:mm').format(ts);
  }
  return DateFormat('MMM d, HH:mm').format(ts);
}

// ── User bubble ───────────────────────────────────────────────────────────

class _UserBubble extends ConsumerStatefulWidget {
  const _UserBubble({required this.message, required this.provider});
  final ChatMessage message;
  final StateNotifierProvider<ChatNotifier, ChatState> provider;

  @override
  ConsumerState<_UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends ConsumerState<_UserBubble> {
  bool _editing = false;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.message.content);
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onLongPress: () => setState(() {
                  _editing = true;
                  _editCtrl.text = widget.message.content;
                }),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      vertical: 4, horizontal: 16),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(5),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppTheme.blue700.withValues(alpha: 0.35),
                          border: Border.all(
                              color: AppTheme.blue500.withValues(alpha: 0.25)),
                        ),
                        child: _editing
                            ? _EditField(
                                controller: _editCtrl,
                                onSave: () {
                                  final text = _editCtrl.text.trim();
                                  if (text.isNotEmpty) {
                                    ref
                                        .read(widget.provider.notifier)
                                        .editAndRegenerate(
                                            widget.message.id, text);
                                  }
                                  setState(() => _editing = false);
                                },
                                onCancel: () =>
                                    setState(() => _editing = false),
                              )
                            : SelectableText(
                                widget.message.content,
                                style: GoogleFonts.sora(
                                    fontSize: 14,
                                    color: AppTheme.textHigh,
                                    height: 1.55),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              // Timestamp + action row
              Padding(
                padding: const EdgeInsets.only(right: 20, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MsgActionBtn(
                      icon: Icons.copy_rounded,
                      tooltip: 'Copy',
                      onTap: () => Clipboard.setData(
                          ClipboardData(text: widget.message.content)),
                    ),
                    _MsgActionBtn(
                      icon: Icons.edit_rounded,
                      tooltip: 'Edit',
                      onTap: () => setState(() {
                        _editing = true;
                        _editCtrl.text = widget.message.content;
                      }),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(widget.message.timestamp),
                      style: GoogleFonts.sora(
                          fontSize: 10, color: AppTheme.textLow),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });
  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: controller,
            maxLines: null,
            autofocus: true,
            style: GoogleFonts.sora(
                fontSize: 14, color: AppTheme.textHigh, height: 1.5),
            cursorColor: AppTheme.blue400,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: onCancel,
              child: Text('Cancel',
                  style: GoogleFonts.sora(
                      fontSize: 11, color: AppTheme.textMid)),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onSave,
              child: Text('Send',
                  style: GoogleFonts.sora(
                      fontSize: 11,
                      color: AppTheme.blue400,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
      );
}

// ── Assistant bubble ──────────────────────────────────────────────────────

class _AssistantBubble extends ConsumerWidget {
  const _AssistantBubble({
    required this.message,
    required this.provider,
    required this.isLast,
  });
  final ChatMessage message;
  final StateNotifierProvider<ChatNotifier, ChatState> provider;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 16),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.blue500.withValues(alpha: 0.06),
                        border: Border.all(
                            color: AppTheme.blue500.withValues(alpha: 0.12)),
                      ),
                      child: message.isStreaming && message.content.isEmpty
                          ? const TypingIndicator()
                          : message.isStreaming
                              ? MarkdownBody(
                                  data: message.content,
                                  selectable: true,
                                  builders: {'code': _CodeBuilder()},
                                  styleSheet: MarkdownStyleSheet(
                                    p: GoogleFonts.sora(
                                        fontSize: 14,
                                        color: AppTheme.textHigh,
                                        height: 1.65),
                                    code: GoogleFonts.dmMono(
                                        fontSize: 13,
                                        color: AppTheme.blue300,
                                        backgroundColor: AppTheme.surface2),
                                    blockquote: GoogleFonts.sora(
                                        fontSize: 14,
                                        color: AppTheme.textMid,
                                        fontStyle: FontStyle.italic),
                                    h1: GoogleFonts.sora(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textHigh),
                                    h2: GoogleFonts.sora(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textHigh),
                                    h3: GoogleFonts.sora(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textHigh),
                                    listBullet: GoogleFonts.sora(
                                        fontSize: 14, color: AppTheme.blue400),
                                    blockSpacing: 12,
                                  ),
                                )
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  child: MarkdownBody(
                                key: ValueKey(
                                    '${message.id}_${message.content.length}'),
                                data: message.content,
                                selectable: true,
                                builders: {'code': _CodeBuilder()},
                              styleSheet: MarkdownStyleSheet(
                                p: GoogleFonts.sora(
                                    fontSize: 14,
                                    color: AppTheme.textHigh,
                                    height: 1.65),
                                code: GoogleFonts.dmMono(
                                    fontSize: 13,
                                    color: AppTheme.blue300,
                                    backgroundColor: AppTheme.surface2),
                                blockquote: GoogleFonts.sora(
                                    fontSize: 14,
                                    color: AppTheme.textMid,
                                    fontStyle: FontStyle.italic),
                                h1: GoogleFonts.sora(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textHigh),
                                h2: GoogleFonts.sora(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textHigh),
                                h3: GoogleFonts.sora(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textHigh),
                                listBullet: GoogleFonts.sora(
                                    fontSize: 14, color: AppTheme.blue400),
                                blockSpacing: 12,
                              ),
                            ),
                    ),
                  ),
                ),
                ),
              ),
              // Timestamp + actions
              if (!message.isStreaming)
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MsgActionBtn(
                        icon: Icons.copy_rounded,
                        tooltip: 'Copy',
                        onTap: () => Clipboard.setData(
                            ClipboardData(text: message.content)),
                      ),
                      if (isLast)
                        _MsgActionBtn(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Regenerate',
                          onTap: () =>
                              ref.read(provider.notifier).regenerateLast(),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: GoogleFonts.sora(
                            fontSize: 10, color: AppTheme.textLow),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}

// ── Tool call bubble (collapsible) ────────────────────────────────────────

class _ToolCallBubble extends StatefulWidget {
  const _ToolCallBubble({required this.message});
  final ChatMessage message;

  @override
  State<_ToolCallBubble> createState() => _ToolCallBubbleState();
}

class _ToolCallBubbleState extends State<_ToolCallBubble>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
        child: GestureDetector(
          onTap: () {
            setState(() => _expanded = !_expanded);
            if (_expanded) { _ctrl.forward(); } else { _ctrl.reverse(); }
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface1,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.blue500.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.blue500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.terminal_rounded,
                            size: 11, color: AppTheme.blue400),
                        const SizedBox(width: 4),
                        Text('Tool call',
                            style: GoogleFonts.dmMono(
                                fontSize: 10,
                                color: AppTheme.blue300,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const Spacer(),
                    Text(
                      _expanded ? 'collapse' : 'expand',
                      style: GoogleFonts.sora(
                          fontSize: 10, color: AppTheme.textLow),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more_rounded,
                          size: 15, color: AppTheme.textMid),
                    ),
                  ]),
                ),
                // Content
                SizeTransition(
                  sizeFactor: _expand,
                  child: Column(children: [
                    Container(
                      height: 1,
                      color: AppTheme.blue500.withValues(alpha: 0.08),
                    ),
                    Container(
                      width: double.infinity,
                      color: const Color(0xFF0D1117),
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        widget.message.content,
                        style: GoogleFonts.dmMono(
                            fontSize: 11,
                            color: AppTheme.textMid,
                            height: 1.6),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Small action button ───────────────────────────────────────────────────

class _MsgActionBtn extends StatefulWidget {
  const _MsgActionBtn(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_MsgActionBtn> createState() => _MsgActionBtnState();
}

class _MsgActionBtnState extends State<_MsgActionBtn> {
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
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppTheme.blue500.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(widget.icon,
                  size: 12, color: AppTheme.textLow),
            ),
          ),
        ),
      );
}

// ── Typing indicator ──────────────────────────────────────────────────────

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 22,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => _Dot(ctrl: _ctrl, delay: i * 0.22),
          ),
        ),
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.ctrl, required this.delay});
  final AnimationController ctrl;
  final double delay;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final t = ((ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
          final dy = t < 0.4
              ? -5 * (t / 0.4)
              : t < 0.7
                  ? -5 * (1 - (t - 0.4) / 0.3)
                  : 0.0;
          final op = 0.35 +
              0.65 *
                  (t < 0.5 ? t / 0.5 : (1 - t) / 0.5).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.blue400.withValues(alpha: op),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      );
}

// ── Code block builder ────────────────────────────────────────────────────

class _CodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(element, TextStyle? preferredStyle) {
    final code = element.textContent;
    // Inline code (no newlines) → let MarkdownStyleSheet.code handle it
    if (!code.contains('\n') && code.length < 80) return null;

    final language = element.attributes['class']
            ?.replaceFirst('language-', '') ??
        'plaintext';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppTheme.blue500.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.surface2.withValues(alpha: 0.6),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                  bottom: BorderSide(
                      color: AppTheme.blue500.withValues(alpha: 0.1))),
            ),
            child: Row(children: [
              Text(language,
                  style: GoogleFonts.dmMono(
                      fontSize: 11,
                      color: AppTheme.textMid,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              _CopyBtn(code: code),
            ]),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(10)),
            child: HighlightView(
              code,
              language: language,
              theme: atomOneDarkTheme,
              padding: const EdgeInsets.all(14),
              textStyle: GoogleFonts.dmMono(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyBtn extends StatefulWidget {
  const _CopyBtn({required this.code});
  final String code;
  @override
  State<_CopyBtn> createState() => _CopyBtnState();
}

class _CopyBtnState extends State<_CopyBtn> {
  bool _copied = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: widget.code));
          setState(() => _copied = true);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) setState(() => _copied = false);
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Row(
            key: ValueKey(_copied),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 13,
                color: _copied ? AppTheme.blue400 : AppTheme.textMid,
              ),
              const SizedBox(width: 4),
              Text(
                _copied ? 'Copied' : 'Copy',
                style: GoogleFonts.sora(
                    fontSize: 11,
                    color: _copied ? AppTheme.blue400 : AppTheme.textMid),
              ),
            ],
          ),
        ),
      );
}
