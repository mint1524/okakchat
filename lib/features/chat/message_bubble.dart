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
  late final Animation<double>  _fade;

  @override
  void initState() {
    super.initState();
    final isUser = widget.message.role == 'user';
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _slide = Tween<Offset>(
      begin: Offset(isUser ? 0.06 : -0.06, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _BubbleContent(message: widget.message),
      ),
    );
  }
}

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isTool = message.role == 'tool';

    // Tool output — compact monospace
    if (isTool) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.blue500.withValues(alpha: 0.15)),
        ),
        child: Text(message.content,
            style: GoogleFonts.dmMono(
                fontSize: 12, color: AppTheme.textMid)),
      );
    }

    // User bubble — right-aligned, blue tint
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.blue700,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(
                  color: AppTheme.blue500.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.blue700.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: -2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(message.content,
                style: GoogleFonts.dmSans(
                    fontSize: 14, color: AppTheme.textHigh,
                    height: 1.5)),
          ),
        ),
      );
    }

    // Assistant bubble — left-aligned, glass-like
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(
                color: AppTheme.blue500.withValues(alpha: 0.12)),
          ),
          child: message.isStreaming && message.content.isEmpty
              ? const _TypingIndicator()
              : MarkdownBody(
                  data: message.isStreaming
                      ? message.content
                      : message.content,
                  builders: {'code': _CodeBuilder()},
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.dmSans(
                        fontSize: 14, color: AppTheme.textHigh, height: 1.6),
                    code: GoogleFonts.dmMono(
                        fontSize: 13,
                        color: AppTheme.blue300,
                        backgroundColor: AppTheme.surface2),
                    blockquote: GoogleFonts.dmSans(
                        fontSize: 14, color: AppTheme.textMid,
                        fontStyle: FontStyle.italic),
                    h1: GoogleFonts.dmSans(fontSize: 20,
                        fontWeight: FontWeight.w700, color: AppTheme.textHigh),
                    h2: GoogleFonts.dmSans(fontSize: 17,
                        fontWeight: FontWeight.w600, color: AppTheme.textHigh),
                    h3: GoogleFonts.dmSans(fontSize: 15,
                        fontWeight: FontWeight.w600, color: AppTheme.textHigh),
                    listBullet: GoogleFonts.dmSans(
                        fontSize: 14, color: AppTheme.blue400),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Typing indicator (3 pulsing dots) ────────────────────────────────────
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
        height: 20,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _Dot(ctrl: _ctrl, delay: i * 0.2)),
        ),
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.ctrl, required this.delay});
  final AnimationController ctrl;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ((ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
        // 0→0.4: up, 0.4→0.7: down, 0.7→1.0: rest
        double dy = 0;
        if (t < 0.4) {
          dy = -4 * (t / 0.4);
        } else if (t < 0.7) {
          dy = -4 * (1 - (t - 0.4) / 0.3);
        }
        final opacity = 0.4 + 0.6 * (t < 0.5 ? t / 0.5 : (1 - t) / 0.5).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: AppTheme.blue400.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Code block with copy button ───────────────────────────────────────────
class _CodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final language =
        element.attributes['class']?.replaceFirst('language-', '') ??
            'plaintext';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.blue500.withValues(alpha: 0.15)),
      ),
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: HighlightView(code,
              language: language,
              theme: atomOneDarkTheme,
              padding: const EdgeInsets.fromLTRB(14, 12, 44, 12),
              textStyle: GoogleFonts.dmMono(fontSize: 13)),
        ),
        Positioned(
          right: 6, top: 6,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => Clipboard.setData(ClipboardData(text: code)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.copy_rounded, size: 14,
                    color: AppTheme.textMid),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
