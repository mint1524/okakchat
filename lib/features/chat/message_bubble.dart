import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'chat_provider.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({super.key, required this.message});
  final ChatMessage message;
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
        vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween<Offset>(
      begin: Offset(isUser ? 0.05 : -0.05, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(
        position: _slide,
        child: _BubbleContent(message: widget.message)),
  );
}

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({required this.message});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    if (message.role == 'tool') return _ToolOutput(content: message.content);
    if (message.role == 'user') return _UserBubble(content: message.content);
    return _AssistantBubble(message: message);
  }
}

// ── User bubble ───────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.content});
  final String content;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.blue700, const Color(0xFF0A4B7A)],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(5),
          ),
          border: Border.all(color: AppTheme.blue500.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(
            color: AppTheme.blue700.withValues(alpha: 0.5),
            blurRadius: 16, spreadRadius: -3, offset: const Offset(0, 4))],
        ),
        child: Text(content, style: GoogleFonts.sora(
            fontSize: 14, color: AppTheme.textHigh, height: 1.55)),
      ),
    ),
  );
}

// ── Assistant bubble (glass) ──────────────────────────────────────────────

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.message});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.blue500.withValues(alpha: 0.06),
                border: Border.all(
                    color: AppTheme.blue500.withValues(alpha: 0.12)),
              ),
              child: message.isStreaming && message.content.isEmpty
                  ? const _TypingIndicator()
                  : MarkdownBody(
                      data: message.content,
                      selectable: true,
                      builders: {'code': _CodeBuilder()},
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.sora(
                            fontSize: 14, color: AppTheme.textHigh, height: 1.65),
                        code: GoogleFonts.dmMono(
                            fontSize: 13, color: AppTheme.blue300,
                            backgroundColor: AppTheme.surface2),
                        blockquote: GoogleFonts.sora(
                            fontSize: 14, color: AppTheme.textMid,
                            fontStyle: FontStyle.italic),
                        h1: GoogleFonts.sora(fontSize: 20,
                            fontWeight: FontWeight.w700, color: AppTheme.textHigh),
                        h2: GoogleFonts.sora(fontSize: 17,
                            fontWeight: FontWeight.w600, color: AppTheme.textHigh),
                        h3: GoogleFonts.sora(fontSize: 15,
                            fontWeight: FontWeight.w600, color: AppTheme.textHigh),
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
  );
}

// ── Tool output (collapsible) ─────────────────────────────────────────────

class _ToolOutput extends StatefulWidget {
  const _ToolOutput({required this.content});
  final String content;
  @override
  State<_ToolOutput> createState() => _ToolOutputState();
}
class _ToolOutputState extends State<_ToolOutput> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
    child: GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.blue500.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.terminal_rounded, size: 13, color: AppTheme.textMid),
            const SizedBox(width: 6),
            Text('Tool output', style: GoogleFonts.sora(
                fontSize: 11, color: AppTheme.textMid,
                fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 14, color: AppTheme.textMid),
          ]),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Text(widget.content, style: GoogleFonts.dmMono(
                fontSize: 11, color: AppTheme.textMid)),
          ],
        ]),
      ),
    ),
  );
}

// ── Typing indicator ──────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}
class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    child: Row(mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => _Dot(ctrl: _ctrl, delay: i * 0.22))),
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
      final dy = t < 0.4 ? -5 * (t / 0.4)
          : t < 0.7 ? -5 * (1 - (t - 0.4) / 0.3) : 0.0;
      final op = 0.35 + 0.65 *
          (t < 0.5 ? t / 0.5 : (1 - t) / 0.5).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: Transform.translate(
          offset: Offset(0, dy),
          child: Container(width: 6, height: 6,
              decoration: BoxDecoration(
                  color: AppTheme.blue400.withValues(alpha: op),
                  shape: BoxShape.circle)),
        ),
      );
    },
  );
}

// ── Code block with language bar + copy ──────────────────────────────────

class _CodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final language = element.attributes['class']
        ?.replaceFirst('language-', '') ?? 'plaintext';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.blue500.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.surface2.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(bottom: BorderSide(
                color: AppTheme.blue500.withValues(alpha: 0.1))),
          ),
          child: Row(children: [
            Text(language, style: GoogleFonts.dmMono(
                fontSize: 11, color: AppTheme.textMid,
                fontWeight: FontWeight.w600)),
            const Spacer(),
            _CopyBtn(code: code),
          ]),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(10)),
          child: HighlightView(code,
              language: language,
              theme: atomOneDarkTheme,
              padding: const EdgeInsets.all(14),
              textStyle: GoogleFonts.dmMono(fontSize: 13)),
        ),
      ]),
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
      child: Row(key: ValueKey(_copied), mainAxisSize: MainAxisSize.min, children: [
        Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
            size: 13,
            color: _copied ? AppTheme.blue400 : AppTheme.textMid),
        const SizedBox(width: 4),
        Text(_copied ? 'Copied' : 'Copy', style: GoogleFonts.sora(
            fontSize: 11,
            color: _copied ? AppTheme.blue400 : AppTheme.textMid)),
      ]),
    ),
  );
}
