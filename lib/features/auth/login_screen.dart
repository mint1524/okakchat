import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/api/api_errors.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/theme/platform_utils.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
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

  Widget _buildMaterial(bool isLoading) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand mark
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'OKAK Chat',
                        style: GoogleFonts.dmSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Sign in to continue',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    // Fields
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passCtrl,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                    ),
                    // Error banner
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline_rounded,
                              size: 16, color: cs.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onErrorContainer)),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // CTA
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/auth/register'),
                          child: Text(
                            'Register',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
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
    );
  }

  Widget _buildCupertino(bool isLoading) => CupertinoPageScaffold(
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeOrange,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(CupertinoIcons.sparkles,
                        color: CupertinoColors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text('OKAK Chat',
                      style: GoogleFonts.dmSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text('Sign in to continue',
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel)),
                ),
                const SizedBox(height: 36),
                _CupertinoField(
                    controller: _emailCtrl,
                    placeholder: 'Email',
                    icon: CupertinoIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next),
                const SizedBox(height: 12),
                _CupertinoField(
                    controller: _passCtrl,
                    placeholder: 'Password',
                    icon: CupertinoIcons.lock,
                    obscureText: true,
                    onSubmitted: (_) => _submit()),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(
                          color: CupertinoColors.destructiveRed, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(10),
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white)
                      : Text('Sign in',
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: () => context.go('/auth/register'),
                      child: Text('Register',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _CupertinoField extends StatelessWidget {
  const _CupertinoField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Icon(icon,
              size: 18, color: CupertinoColors.secondaryLabel),
        ),
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(10),
        ),
      );
}
