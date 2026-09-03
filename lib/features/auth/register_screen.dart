import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/premium/premium_button.dart';
import '../../core/providers/providers.dart';
import 'auth_layout.dart';
import 'auth_layout_web.dart';

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
  bool _adminCodeObscure = true;
  bool _showAdminCode = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authProvider.notifier)
        .register(
          _name.text,
          _email.text,
          _password.text,
          adminCode: _showAdminCode && _adminCode.text.trim().isNotEmpty
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
    _adminCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final error = auth.error;

    final title = 'Create your vault';
    final subtitle = 'Start building your private art collection';
    final footer = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Already have an account?'),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Sign in'),
        ),
      ],
    );
    final children = <Widget>[
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
          children: staggerReveal(
            [
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
                maxLength: Validators.maxEmailLength,
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: _obscure,
                maxLength: Validators.maxPasswordLength,
                validator: Validators.password,
                textInputAction: TextInputAction.next,
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
                maxLength: Validators.maxPasswordLength,
                validator: (v) => Validators.passwordConfirm(v, _password.text),
                textInputAction: TextInputAction.done,
                suffixIcon: IconButton(
                  tooltip: _confirmObscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _confirmObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _confirmObscure = !_confirmObscure),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _showAdminCode = !_showAdminCode),
                icon: Icon(_showAdminCode ? Icons.expand_less : Icons.admin_panel_settings_outlined, size: 18),
                label: Text(_showAdminCode ? 'Hide admin setup code' : 'First admin? Enter setup code'),
              ),
              if (_showAdminCode) ...[
                const SizedBox(height: AppSpacing.xs),
                AppTextField(
                  controller: _adminCode,
                  label: 'Admin setup code',
                  icon: Icons.key_outlined,
                  obscureText: _adminCodeObscure,
                  textInputAction: TextInputAction.done,
                  suffixIcon: IconButton(
                    tooltip: _adminCodeObscure ? 'Show code' : 'Hide code',
                    icon: Icon(_adminCodeObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    onPressed: () => setState(() => _adminCodeObscure = !_adminCodeObscure),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              PremiumButton(label: 'Create Account', loading: auth.busy, onPressed: _submit),
            ],
            initialDelay: const Duration(milliseconds: 100),
            context: context,
          ),
        ),
      ),
    ];
    if (kIsWeb) {
      return AuthLayoutWeb(title: title, subtitle: subtitle, footer: footer, children: children);
    }
    return AuthLayout(title: title, subtitle: subtitle, footer: footer, children: children);
  }
}
