/// Shared widgets for auth screens (login / register / verify).
/// Public so all three files can import them.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';

// ── Dark text field ───────────────────────────────────────────────────────

class AuthDarkField extends StatelessWidget {
  const AuthDarkField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: GoogleFonts.spaceGrotesk(fontSize: 14, color: AppTheme.textHigh),
        cursorColor: AppTheme.blue400,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.spaceGrotesk(fontSize: 13, color: AppTheme.textMid),
          prefixIcon: Icon(icon, size: 18, color: AppTheme.textMid),
          suffixIcon: suffix,
          filled: true,
          fillColor: AppTheme.surface1,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: AppTheme.blue500.withValues(alpha: 0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: AppTheme.blue500.withValues(alpha: 0.6), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}

// ── Error banner ──────────────────────────────────────────────────────────

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF5C1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFFF87171).withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: Color(0xFFF87171)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: const Color(0xFFFCA5A5))),
          ),
        ]),
      );
}

// ── Glow button ───────────────────────────────────────────────────────────

class AuthGlowButton extends StatelessWidget {
  const AuthGlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: AppTheme.blue500.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.blue500,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppTheme.blue700.withValues(alpha: 0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            textStyle: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label),
        ),
      );
}

// ── Brand icon ────────────────────────────────────────────────────────────

class AuthBrandIcon extends StatelessWidget {
  const AuthBrandIcon({super.key, this.icon = Icons.auto_awesome_rounded});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.blue700,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppTheme.blue500.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.blue500.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      );
}
