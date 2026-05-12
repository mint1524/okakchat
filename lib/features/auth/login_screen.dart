import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/api/api_errors.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'package:okakchat/core/theme/platform_utils.dart';
import 'package:okakchat/core/widgets/animated_background.dart';
import 'package:okakchat/core/widgets/glass_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  String? _error;
  bool _obscure = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      await ref
          .read(authProvider.notifier)
          .login(_emailCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    if (PlatformUtils.isIOS) return _buildCupertino(isLoading);
    return _buildMaterial(isLoading);
  }

  Widget _buildMaterial(bool isLoading) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: AnimatedBackground(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: GlassCard(
                      glowOpacity: 0.12,
                      backgroundOpacity: 0.1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Brand
                          Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.blue700,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppTheme.blue500
                                        .withValues(alpha: 0.4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.blue500
                                        .withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.white, size: 28),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: Text(
                              'OKAK Chat',
                              style: GoogleFonts.dmSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textHigh,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: Text(
                              'Sign in to continue',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, color: AppTheme.textMid),
                            ),
                          ),
                          const SizedBox(height: 28),
                          // Fields
                          _DarkField(
                            controller: _emailCtrl,
                            label: 'Email',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _DarkField(
                            controller: _passCtrl,
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscure,
                            onSubmitted: (_) => _submit(),
                            suffix: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18, color: AppTheme.textMid,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            _ErrorBanner(message: _error!),
                          ],
                          const SizedBox(height: 20),
                          _GlowButton(
                              label: 'Sign in',
                              onPressed: isLoading ? null : _submit,
                              isLoading: isLoading),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Don't have an account? ",
                                  style: GoogleFonts.dmSans(
                                      fontSize: 12, color: AppTheme.textMid)),
                              GestureDetector(
                                onTap: () => context.go('/auth/register'),
                                child: Text('Register',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: AppTheme.blue400,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildCupertino(bool isLoading) => CupertinoPageScaffold(
        backgroundColor: AppTheme.bg,
        child: AnimatedBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  glowOpacity: 0.1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.blue700,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(
                              color: AppTheme.blue500.withValues(alpha: 0.3),
                              blurRadius: 20)],
                          ),
                          child: const Icon(CupertinoIcons.sparkles,
                              color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(child: Text('OKAK Chat', style: GoogleFonts.dmSans(
                          fontSize: 22, fontWeight: FontWeight.w700,
                          color: AppTheme.textHigh))),
                      const SizedBox(height: 22),
                      _IosDarkField(controller: _emailCtrl, placeholder: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next),
                      const SizedBox(height: 10),
                      _IosDarkField(controller: _passCtrl, placeholder: 'Password',
                          obscureText: true, onSubmitted: (_) => _submit()),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        _ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 20),
                      _GlowButton(label: 'Sign in',
                          onPressed: isLoading ? null : _submit,
                          isLoading: isLoading),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text("No account? ", style: GoogleFonts.dmSans(
                            fontSize: 12, color: AppTheme.textMid)),
                        CupertinoButton(
                          padding: EdgeInsets.zero, minSize: 0,
                          onPressed: () => context.go('/auth/register'),
                          child: Text('Register', style: GoogleFonts.dmSans(
                              fontSize: 12, color: AppTheme.blue400)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

// ── Shared sub-widgets ────────────────────────────────────────────────────

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller, required this.label, required this.icon,
    this.obscureText = false, this.keyboardType, this.textInputAction,
    this.onSubmitted, this.suffix,
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
        controller: controller, obscureText: obscureText,
        keyboardType: keyboardType, textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.textHigh),
        cursorColor: AppTheme.blue400,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMid),
          prefixIcon: Icon(icon, size: 18, color: AppTheme.textMid),
          suffixIcon: suffix,
          filled: true,
          fillColor: AppTheme.surface1,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.blue500.withValues(alpha: 0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: AppTheme.blue500.withValues(alpha: 0.6), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}

class _IosDarkField extends StatelessWidget {
  const _IosDarkField({
    required this.controller, required this.placeholder,
    this.obscureText = false, this.keyboardType, this.textInputAction,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String placeholder;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        placeholderStyle: TextStyle(color: AppTheme.textMid, fontSize: 14),
        style: TextStyle(color: AppTheme.textHigh, fontSize: 14),
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        cursorColor: AppTheme.blue400,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.blue500.withValues(alpha: 0.2)),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF5C1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFFF87171).withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, size: 15,
              color: Color(0xFFF87171)),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: const Color(0xFFFCA5A5)))),
        ]),
      );
}

class _GlowButton extends StatelessWidget {
  const _GlowButton({required this.label, required this.onPressed,
      this.isLoading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: onPressed != null
              ? [BoxShadow(
                  color: AppTheme.blue500.withValues(alpha: 0.35),
                  blurRadius: 20, spreadRadius: -2,
                  offset: const Offset(0, 4))]
              : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.blue500,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.blue700.withValues(alpha: 0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            textStyle: GoogleFonts.dmSans(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
          child: isLoading
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label),
        ),
      );
}
