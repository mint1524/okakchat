import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Particle shape formation modes
enum ParticleFormation {
  none,
  circle,
  hammer,
  code,
  brain,
  gear,
}

/// Animated particle background with shape formation and mouse parallax.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({
    super.key,
    this.child,
    this.particleCount = 28,
    this.parallax = false,
    this.formation = ParticleFormation.none,
    this.formationProgress = 0.0,
  });
  final Widget? child;
  final int particleCount;
  final bool parallax;
  final ParticleFormation formation;
  final double formationProgress;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;
  final _rng = math.Random();

  Offset _mouse = Offset.zero;
  Offset _parallax1 = Offset.zero;
  Offset _parallax2 = Offset.zero;

  @override
  void didUpdateWidget(AnimatedBackground old) {
    super.didUpdateWidget(old);
    if (old.particleCount != widget.particleCount) {
      while (_particles.length < widget.particleCount) {
        _particles.add(_Particle.random(_rng));
      }
      while (_particles.length > widget.particleCount) {
        _particles.removeLast();
      }
    }
    if (old.formation != widget.formation) {
      _assignShapeTargets();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _assignShapeTargets() {
    final targets = _shapeTargets(widget.formation, _particles.length);
    for (int i = 0; i < _particles.length; i++) {
      if (i < targets.length) {
        _particles[i].targetX = targets[i].dx;
        _particles[i].targetY = targets[i].dy;
      }
    }
  }

  List<Offset> _shapeTargets(ParticleFormation formation, int count) {
    switch (formation) {
      case ParticleFormation.none:
        return List.generate(count, (_) => Offset(-1, -1));
      case ParticleFormation.circle:
        return _circleShape(count);
      case ParticleFormation.hammer:
        return _hammerShape(count);
      case ParticleFormation.code:
        return _codeShape(count);
      case ParticleFormation.brain:
        return _brainShape(count);
      case ParticleFormation.gear:
        return _gearShape(count);
    }
  }

  List<Offset> _circleShape(int n) {
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final angle = (i / n) * math.pi * 2;
      final r = 0.3 + 0.08 * (i % 3 - 1);
      pts.add(Offset(0.5 + r * math.cos(angle), 0.5 + r * math.sin(angle)));
    }
    return pts;
  }

  List<Offset> _hammerShape(int n) {
    final pts = <Offset>[];
    final handleEnd = 0.5;
    final headW = 0.18;
    for (int i = 0; i < n; i++) {
      final t = i / n;
      if (t < 0.4) {
        final ht = t / 0.4;
        pts.add(Offset(0.5 - handleEnd * (1 - ht), 0.5));
      } else if (t < 0.55) {
        pts.add(Offset(0.5 - headW + (t - 0.4) / 0.15 * headW * 2, 0.5 - 0.12));
      } else if (t < 0.7) {
        pts.add(Offset(0.5 + headW, 0.5 - 0.12 + (t - 0.55) / 0.15 * 0.24));
      } else if (t < 0.85) {
        pts.add(Offset(0.5 + headW - (t - 0.7) / 0.15 * headW * 2, 0.5 + 0.12));
      } else {
        pts.add(Offset(0.5 - headW, 0.5 + 0.12 - (t - 0.85) / 0.15 * 0.12));
      }
    }
    return pts;
  }

  List<Offset> _codeShape(int n) {
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final t = i / n;
      if (t < 0.25) {
        final lt = t / 0.25;
        pts.add(Offset(0.25 + lt * 0.25, 0.5 - 0.08 * math.sin(lt * math.pi)));
      } else if (t < 0.5) {
        final lt = (t - 0.25) / 0.25;
        pts.add(Offset(0.5 + lt * 0.15, 0.3 + lt * 0.15));
      } else if (t < 0.75) {
        final lt = (t - 0.5) / 0.25;
        pts.add(Offset(0.65 - lt * 0.15, 0.45 + lt * 0.15));
      } else {
        final lt = (t - 0.75) / 0.25;
        pts.add(Offset(0.5 - lt * 0.25, 0.6 - lt * 0.1));
      }
    }
    return pts;
  }

  List<Offset> _brainShape(int n) {
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final t = i / n;
      final a = t * math.pi * 2;
      final r = 0.25 + 0.08 * math.sin(a * 3);
      pts.add(Offset(0.5 + r * math.cos(a), 0.5 + r * math.sin(a) * 0.85));
    }
    return pts;
  }

  List<Offset> _gearShape(int n) {
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2;
      final tooth = (a % (math.pi / 4)) < (math.pi / 12);
      final r = tooth ? 0.35 : 0.28;
      pts.add(Offset(0.5 + r * math.cos(a), 0.5 + r * math.sin(a)));
    }
    return pts;
  }

  void _onMouseMove(PointerEvent evt, Size size) {
    _mouse = Offset(
      (evt.localPosition.dx / size.width - 0.5) * 2,
      (evt.localPosition.dy / size.height - 0.5) * 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onHover: widget.parallax ? (e) => _onMouseMove(e, size) : null,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final formation = widget.formation;
              final progress = widget.formationProgress;

              for (final p in _particles) {
                p.update(drift: formation == ParticleFormation.none);
                if (formation != ParticleFormation.none && p.targetX >= 0) {
                  final targetDx = p.targetX - p.x;
                  final targetDy = p.targetY - p.y;
                  final dist = math.sqrt(targetDx * targetDx + targetDy * targetDy);
                  if (dist > 0.002) {
                    final speed = 0.04 + 0.04 * progress;
                    p.x += targetDx * speed;
                    p.y += targetDy * speed;
                  } else {
                    p.x = p.targetX;
                    p.y = p.targetY;
                  }
                }
              }

              if (widget.parallax) {
                const sp = 0.05;
                _parallax1 = Offset.lerp(_parallax1, _mouse * 28, sp)!;
                _parallax2 = Offset.lerp(_parallax2, _mouse * 56, sp)!;
              }
              return CustomPaint(
                painter: _ParticlePainter(_particles, _parallax1, _parallax2),
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
    x = rng.nextDouble();
    y = rng.nextDouble();
    vx = (rng.nextDouble() - 0.5) * 0.00065;
    vy = (rng.nextDouble() - 0.5) * 0.00065;
    size = rng.nextDouble() * 1.8 + 0.8;
    opacity = rng.nextDouble() * 0.4 + 0.15;
  }

  double x = 0, y = 0, vx = 0, vy = 0, size = 1, opacity = 0.3;
  double targetX = -1, targetY = -1;

  void update({bool drift = true}) {
    if (drift) {
      x += vx;
      y += vy;
      if (x < 0) x += 1;
      if (x > 1) x -= 1;
      if (y < 0) y += 1;
      if (y > 1) y -= 1;
    }
  }
}

// ── Painter ───────────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles,
      [this.parallax1 = Offset.zero, this.parallax2 = Offset.zero]);
  final List<_Particle> particles;
  final Offset parallax1;
  final Offset parallax2;

  static const _connectionDistance = 0.22;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint();
    final bgRect = Offset.zero & size;
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
          linePaint.color =
              AppTheme.blue500.withValues(alpha: fade * 0.12);
          canvas.drawLine(
            Offset(a.x * size.width, a.y * size.height),
            Offset(b.x * size.width, b.y * size.height),
            linePaint,
          );
        }
      }
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final offset = i.isEven ? parallax1 : parallax2;
      dotPaint.color = AppTheme.blue400.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width + offset.dx, p.y * size.height + offset.dy),
        p.size,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

/// Compact ambient animation for panels/cards.
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
