import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/motion.dart';
import '../../core/providers/providers.dart';
import 'auth_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _adminCode = TextEditingController();
  // Per-field obscurity so revealing one password never reveals the other,
  // matching the login screen's suffix-eye-toggle pattern.
  bool _obscure = true;
  bool _confirmObscure = true;
  bool _showAdminCode = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(authProvider.notifier).register(
          _name.text,
          _email.text,
          _password.text,
          adminCode:
              _showAdminCode && _adminCode.text.trim().isNotEmpty
              ? _adminCode.text.trim()
              : null,
        );
    if (ok && mounted) context.go('/home');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final error = auth.error;

    return AuthLayout(
      title: 'Create your vault',
      subtitle: 'Start building your private art collection',
      // Wrap (not Row) so the 'Sign in' action drops to its own line
      // rather than overflowing the card on narrow widths.
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Already have an account?'),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in'),
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
            child: Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),
        Form(
          key: _formKey,
          child: Column(
            // Fields cascade in one by one, matching the login screen and
            // the cinematic splash intro.
            children: staggerReveal([
              AppTextField(
                controller: _name,
                label: 'Full name',
                hint: 'Alexandra Restrepo',
                icon: Icons.person_outline,
                capitalization: TextCapitalization.words,
                validator: Validators.name,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: _obscure,
                validator: Validators.password,
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _confirm,
                label: 'Confirm password',
                icon: Icons.lock_outline,
                obscureText: _confirmObscure,
                validator: (v) => Validators.passwordConfirm(v, _password.text),
                textInputAction: TextInputAction.done,
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmObscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _confirmObscure = !_confirmObscure),
                ),
              ),
              // Optional one-time setup: the very first account can become
              // admin with the bootstrap code created in Firestore
              // (bootstrap/config.adminCode). Hidden by default so everyday
              // sign-ups never see it.
              TextButton.icon(
                onPressed: () => setState(() => _showAdminCode = !_showAdminCode),
                icon: Icon(
                  _showAdminCode
                      ? Icons.expand_less
                      : Icons.admin_panel_settings_outlined,
                  size: 18,
                ),
                label: Text(
                  _showAdminCode
                      ? 'Hide admin setup code'
                      : 'First admin? Enter setup code',
                ),
              ),
              if (_showAdminCode) ...[
                const SizedBox(height: AppSpacing.xs),
                AppTextField(
                  controller: _adminCode,
                  label: 'Admin setup code',
                  icon: Icons.key_outlined,
                  textInputAction: TextInputAction.done,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Create Account',
                loading: auth.busy,
                onPressed: _submit,
              ),
            ], initialDelay: const Duration(milliseconds: 100), context: context),
          ),
        ),
      ],
    );
  }
}
