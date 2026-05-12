import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated particle background with optional mouse parallax.
/// 28 drifting dots with connecting lines. Canvas-only.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({
    super.key,
    this.child,
    this.particleCount = 28,
    this.parallax = false,
  });
  final Widget? child;
  final int particleCount;
  /// Enable mouse-tracking parallax (desktop/web only)
  final bool parallax;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;
  final _rng = math.Random();

  // Parallax offsets — smoothly lerp toward mouse position
  Offset _mouse = Offset.zero;
  Offset _parallax1 = Offset.zero; // slow layer (depth 1)
  Offset _parallax2 = Offset.zero; // fast layer (depth 2)

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

  void _onMouseMove(PointerEvent evt, Size size) {
    _mouse = Offset(
      (evt.localPosition.dx / size.width  - 0.5) * 2,
      (evt.localPosition.dy / size.height - 0.5) * 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onHover: widget.parallax
              ? (e) => _onMouseMove(e, size)
              : null,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              for (final p in _particles) p.update();
              // Smoothly lerp parallax offsets
              if (widget.parallax) {
                const speed = 0.05;
                _parallax1 = Offset.lerp(
                    _parallax1, _mouse * 28, speed)!;
                _parallax2 = Offset.lerp(
                    _parallax2, _mouse * 56, speed)!;
              }
              return CustomPaint(
                painter: _ParticlePainter(
                    _particles, _parallax1, _parallax2),
                child: widget.child,
              );
            },
          ),
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
    // Visible but not distracting — 5-6× faster than before
    vx = (rng.nextDouble() - 0.5) * 0.00065;
    vy = (rng.nextDouble() - 0.5) * 0.00065;
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
  _ParticlePainter(this.particles,
      [this.parallax1 = Offset.zero, this.parallax2 = Offset.zero]);
  final List<_Particle> particles;
  final Offset parallax1; // slow layer offset in pixels
  final Offset parallax2; // fast layer offset in pixels

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

    // Dots — odd-indexed particles shift more (parallax depth 2)
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final offset = i.isEven ? parallax1 : parallax2;
      dotPaint.color = AppTheme.blue400.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width + offset.dx,
               p.y * size.height + offset.dy),
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
