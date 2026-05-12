import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated particle background — 28 slowly drifting blue dots
/// with connecting lines. Canvas-only, ~0% CPU overhead.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, this.child, this.particleCount = 28});
  final Widget? child;
  final int particleCount;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _particles = List.generate(
        widget.particleCount, (_) => _Particle.random(_rng));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        for (final p in _particles) {
          p.update();
        }
        return CustomPaint(
          painter: _ParticlePainter(_particles),
          child: widget.child,
        );
      },
    );
  }
}

// ── Particle data ─────────────────────────────────────────────────────────
class _Particle {
  _Particle.random(math.Random rng) {
    x  = rng.nextDouble();
    y  = rng.nextDouble();
    // Very slow random velocity
    vx = (rng.nextDouble() - 0.5) * 0.00012;
    vy = (rng.nextDouble() - 0.5) * 0.00012;
    size   = rng.nextDouble() * 1.8 + 0.8;
    opacity = rng.nextDouble() * 0.4 + 0.15;
  }

  double x = 0, y = 0, vx = 0, vy = 0, size = 1, opacity = 0.3;

  void update() {
    x += vx;
    y += vy;
    // Wrap around
    if (x < 0) x += 1;
    if (x > 1) x -= 1;
    if (y < 0) y += 1;
    if (y > 1) y -= 1;
  }
}

// ── Painter ───────────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles);
  final List<_Particle> particles;

  static const _connectionDistance = 0.22; // fraction of screen width

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    final bgPaint = Paint();
    final bgRect  = Offset.zero & size;
    bgPaint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF060B17),
        Color(0xFF080F1E),
        Color(0xFF060B17),
      ],
      stops: [0.0, 0.5, 1.0],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Connection lines
    final linePaint = Paint()
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final a = particles[i];
        final b = particles[j];
        final dx = (a.x - b.x).abs();
        final dy = (a.y - b.y).abs();
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < _connectionDistance) {
          final fade = 1.0 - dist / _connectionDistance;
          linePaint.color = AppTheme.blue500
              .withValues(alpha: fade * 0.12);
          canvas.drawLine(
            Offset(a.x * size.width, a.y * size.height),
            Offset(b.x * size.width, b.y * size.height),
            linePaint,
          );
        }
      }
    }

    // Dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      dotPaint.color = AppTheme.blue400.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

/// Compact ambient animation — smaller, for panels/cards backgrounds.
/// Just a subtle gradient shift, no particles.
class AmbientGlow extends StatefulWidget {
  const AmbientGlow({super.key, required this.child});
  final Widget child;

  @override
  State<AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<AmbientGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                math.sin(t * math.pi * 2) * 0.3,
                math.cos(t * math.pi * 2) * 0.3,
              ),
              radius: 1.2,
              colors: [
                AppTheme.blue700.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
