import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/api/api_errors.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'package:okakchat/core/widgets/animated_background.dart';
import 'package:okakchat/core/widgets/glass_card.dart';
import 'login_screen.dart'; // re-uses _DarkField, _GlowButton, _ErrorBanner

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  String? _error;
  bool _loading = false;
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
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _error = null; _loading = true; });
    try {
      final result = await ref.read(authProvider.notifier).register(
          _emailCtrl.text.trim(), _passCtrl.text, _nameCtrl.text.trim());
      if (mounted) {
        context.go('/auth/verify?userId=${result.userId}'
            '&email=${Uri.encodeComponent(result.email)}');
      }
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: AnimatedBackground(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: GlassCard(
                      glowOpacity: 0.12,
                      backgroundOpacity: 0.1,
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
                                border: Border.all(
                                    color: AppTheme.blue500.withValues(alpha: 0.4)),
                                boxShadow: [BoxShadow(
                                    color: AppTheme.blue500.withValues(alpha: 0.3),
                                    blurRadius: 20, spreadRadius: -2)],
                              ),
                              child: const Icon(Icons.auto_awesome_rounded,
                                  color: Colors.white, size: 28),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Center(child: Text('Create account',
                              style: GoogleFonts.dmSans(fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textHigh, letterSpacing: -0.5))),
                          const SizedBox(height: 4),
                          Center(child: Text('Join OKAK Chat',
                              style: GoogleFonts.dmSans(fontSize: 13,
                                  color: AppTheme.textMid))),
                          const SizedBox(height: 28),
                          _DarkField(controller: _nameCtrl, label: 'Display name',
                              icon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next),
                          const SizedBox(height: 12),
                          _DarkField(controller: _emailCtrl, label: 'Email',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next),
                          const SizedBox(height: 12),
                          _DarkField(
                            controller: _passCtrl,
                            label: 'Password (8+ chars)',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscure,
                            onSubmitted: (_) => _submit(),
                            suffix: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_off_outlined
                                         : Icons.visibility_outlined,
                                size: 18, color: AppTheme.textMid),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            _ErrorBanner(message: _error!),
                          ],
                          const SizedBox(height: 20),
                          _GlowButton(label: 'Create account',
                              onPressed: _loading ? null : _submit,
                              isLoading: _loading),
                          const SizedBox(height: 16),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('Already have an account? ',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12, color: AppTheme.textMid)),
                            GestureDetector(
                              onTap: () => context.go('/auth/login'),
                              child: Text('Sign in', style: GoogleFonts.dmSans(
                                  fontSize: 12, color: AppTheme.blue400,
                                  fontWeight: FontWeight.w600)),
                            ),
                          ]),
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
}
