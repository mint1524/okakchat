import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Glassmorphism card — frosted blur + blue-tinted border.
///
/// Requires something behind it to blur (e.g. AnimatedBackground).
/// Usage: wrap content in GlassCard(..., child: ...).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(24),
    this.blurSigma = 24.0,
    this.backgroundOpacity = 0.08,
    this.borderOpacity = 0.18,
    this.glowOpacity = 0.0,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final double backgroundOpacity;
  final double borderOpacity;
  final double glowOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: glowOpacity > 0
            ? [
                BoxShadow(
                  color: AppTheme.blue500.withValues(alpha: glowOpacity),
                  blurRadius: 40,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppTheme.blue500.withValues(alpha: backgroundOpacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: AppTheme.blue500.withValues(alpha: borderOpacity),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Thin glass surface — same as GlassCard but no padding, for wrappers.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 12.0,
    this.blurSigma = 16.0,
    this.backgroundOpacity = 0.06,
    this.borderOpacity = 0.12,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double backgroundOpacity;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.blue500.withValues(alpha: backgroundOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: AppTheme.blue500.withValues(alpha: borderOpacity),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
