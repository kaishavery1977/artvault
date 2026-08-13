import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/biometric_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/motion.dart';
import '../../core/providers/providers.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _obscure = true;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final enabled =
        await AuthRepository.instance.biometricEnabled ||
        await AuthRepository.instance.faceLockEnabled;
    if (enabled) {
      final available = await BiometricService.instance.isAvailable;
      setState(() => _biometricAvailable = available);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authProvider.notifier)
        .signInWithEmail(_email.text, _password.text, remember: _remember);
    if (ok && mounted) context.go('/home');
  }

  Future<void> _google() async {
    final ok = await ref.read(authProvider.notifier).signInWithGoogle();
    if (ok && mounted) context.go('/home');
  }

  Future<void> _apple() async {
    final ok = await ref.read(authProvider.notifier).signInWithApple();
    if (ok && mounted) context.go('/home');
  }

  Future<void> _biometric() async {
    final repo = AuthRepository.instance;
    if (!await repo.hasRememberedSession) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enable biometrics from Security settings after signing in.',
          ),
        ),
      );
      return;
    }
    if (!await BiometricService.instance.authenticate()) return;
    final current = ref.read(authProvider).status;
    if (current == AuthStatus.authenticated) {
      if (mounted) context.go('/home');
      return;
    }
    await ref.read(authProvider.notifier).bootstrap();
    if (mounted && ref.read(authProvider).status == AuthStatus.authenticated) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final error = auth.error;

    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to open your private gallery',
      // Wrap instead of Row: on narrow widths or large text scales the
      // 'Create one' action drops to its own line rather than overflowing
      // the card, matching the 'Remember me' row treatment.
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text("Don't have an account?"),
          TextButton(
            onPressed: () => context.push('/register'),
            child: const Text('Create one'),
          ),
        ],
      ),
      children: [
        if (error != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Form(
          key: _formKey,
          child: Column(
            // Fields cascade in one by one — matches the cinematic splash
            // intro. Index-stable, so toggling the visibility switch or
            // remember-me never replays the animation.
            children: staggerReveal([
              AppTextField(
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: _obscure,
                validator: Validators.password,
                textInputAction: TextInputAction.done,
                onChanged: (_) {},
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Wrap instead of Row: on narrow widths or large text scales
              // the 'Forgot password?' action drops to its own line rather
              // than overflowing the card. When it fits, spaceBetween keeps
              // the two sides at the card edges.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: _remember,
                        onChanged: (v) => setState(() => _remember = v),
                      ),
                      const SizedBox(width: 4),
                      const Text('Remember me'),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.push('/forgot'),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Sign In',
                loading: auth.busy,
                onPressed: _submit,
              ),
            ], initialDelay: const Duration(milliseconds: 300)),
          ),
        ),
        if (_biometricAvailable) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _biometric,
            icon: const Icon(Icons.fingerprint, size: 20),
            label: const Text('Unlock with biometrics'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const AuthDivider(),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _google,
                icon: const Icon(Icons.g_mobiledata, size: 26),
                label: const Text('Google'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _apple,
                icon: const Icon(Icons.apple, size: 22),
                label: const Text('Apple'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
