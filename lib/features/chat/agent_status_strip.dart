import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';

/// Phases used by the bottom agent status strip.
///
/// `chat` screen will only use [idle], [thinking] and [streaming]; the
/// `code` screen uses the tool-specific phases as well.
enum AgentPhase {
  idle,
  thinking,
  streaming,
  reading,
  writing,
  editing,
  searching,
  listing,
  running,
}

/// Thin Claude-Code / OpenCode-style status strip rendered directly above
/// the chat input.  It shows an orbiting indicator, a morphing phase icon,
/// a label (`Thinking…` / `Reading file…` …), elapsed time + tokens, and an
/// optional `Stop` action.
///
/// Designed to be cheap: only the orbit ticker repaints — the surrounding
/// row uses [AnimatedSwitcher] for icon morphing.
class AgentStatusStrip extends StatefulWidget {
  const AgentStatusStrip({
    super.key,
    required this.phase,
    required this.label,
    required this.elapsedSec,
    required this.tokens,
    this.onCancel,
  });

  final AgentPhase phase;
  final String label;
  final int elapsedSec;
  final int tokens;
  final VoidCallback? onCancel;

  @override
  State<AgentStatusStrip> createState() => _AgentStatusStripState();
}

class _AgentStatusStripState extends State<AgentStatusStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData get _phaseIcon {
    switch (widget.phase) {
      case AgentPhase.reading:
        return Icons.description_outlined;
      case AgentPhase.writing:
        return Icons.edit_note_rounded;
      case AgentPhase.editing:
        return Icons.edit_outlined;
      case AgentPhase.searching:
        return Icons.search_rounded;
      case AgentPhase.listing:
        return Icons.folder_open_rounded;
      case AgentPhase.running:
        return Icons.terminal_rounded;
      case AgentPhase.streaming:
        return Icons.auto_awesome_outlined;
      case AgentPhase.thinking:
        return Icons.psychology_outlined;
      case AgentPhase.idle:
        return Icons.circle_outlined;
    }
  }

  String _fmtTokens(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  String _fmtElapsed(int s) {
    if (s <= 0) return '';
    if (s < 60) return '${s}s';
    return '${s ~/ 60}m ${s % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    final elapsedStr = _fmtElapsed(widget.elapsedSec);
    final tokensStr = widget.tokens > 0 ? _fmtTokens(widget.tokens) : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
      decoration: BoxDecoration(
        color: AppTheme.blue500.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: AppTheme.blue500.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          // Animated orbit + morphing phase glyph
          SizedBox(
            width: 22,
            height: 22,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _OrbitPainter(
                  t: _ctrl.value,
                  color: AppTheme.blue400,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (c, a) => ScaleTransition(
                      scale: a,
                      child: FadeTransition(opacity: a, child: c),
                    ),
                    child: Icon(
                      _phaseIcon,
                      key: ValueKey(widget.phase),
                      size: 11,
                      color: AppTheme.blue300,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Label + ellipsis pulse
          Flexible(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final dots = (_ctrl.value * 3).floor() % 4;
                final ellipsis = '.' * dots;
                return Text(
                  '${widget.label}$ellipsis',
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    color: AppTheme.blue300,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          if (elapsedStr.isNotEmpty || tokensStr.isNotEmpty) ...[
            const SizedBox(width: 12),
            if (elapsedStr.isNotEmpty)
              Text(
                elapsedStr,
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  color: AppTheme.textLow,
                ),
              ),
            if (tokensStr.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(Icons.north_rounded, size: 9, color: AppTheme.textLow),
              const SizedBox(width: 2),
              Text(
                '$tokensStr tok',
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  color: AppTheme.textLow,
                ),
              ),
            ],
          ],
          const Spacer(),
          if (widget.onCancel != null)
            InkWell(
              onTap: widget.onCancel,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.stop_circle_outlined,
                      size: 12, color: AppTheme.textMid),
                  const SizedBox(width: 4),
                  Text('Stop',
                      style: GoogleFonts.dmMono(
                          fontSize: 10, color: AppTheme.textMid)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three small dots orbiting a centre, alpha pulsing as they swing.
class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 2.0;
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      final a = t * 2 * math.pi + i * (2 * math.pi / 3);
      final dx = c.dx + r * math.cos(a);
      final dy = c.dy + r * math.sin(a);
      // Front dots (sin > 0) brighter, back dots fade out.
      final depth = (math.sin(a) + 1) / 2;
      paint.color = color.withValues(alpha: 0.25 + 0.65 * depth);
      canvas.drawCircle(Offset(dx, dy), 1.4 + 0.4 * depth, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t || old.color != color;
}
