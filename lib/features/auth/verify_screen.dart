import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/api/api_errors.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'package:okakchat/core/widgets/animated_background.dart';
import 'package:okakchat/core/widgets/glass_card.dart';
import 'auth_widgets.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.userId, required this.email});
  final String userId, email;
  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen>
    with SingleTickerProviderStateMixin {
  final _codeCtrl = TextEditingController();
  String? _error;

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
    _codeCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      await ref
          .read(authProvider.notifier)
          .verify(widget.userId, _codeCtrl.text.trim());
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    return Scaffold(
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
                        Center(
                          child: AuthBrandIcon(
                              icon: Icons.mark_email_unread_outlined),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Text('Verify email',
                              style: GoogleFonts.sora(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textHigh,
                                  letterSpacing: -0.5)),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                              'Code sent to\n${widget.email}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sora(
                                  fontSize: 13, color: AppTheme.textMid)),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _codeCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.sora(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 14,
                              color: AppTheme.textHigh),
                          cursorColor: AppTheme.blue400,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '------',
                            hintStyle: GoogleFonts.sora(
                                fontSize: 34,
                                letterSpacing: 14,
                                color: AppTheme.textLow),
                            filled: true,
                            fillColor: AppTheme.surface1,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppTheme.blue500
                                      .withValues(alpha: 0.18)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppTheme.blue500
                                      .withValues(alpha: 0.6),
                                  width: 1.5),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          AuthErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 20),
                        AuthGlowButton(
                            label: 'Verify',
                            onPressed: isLoading ? null : _submit,
                            isLoading: isLoading),
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
}
