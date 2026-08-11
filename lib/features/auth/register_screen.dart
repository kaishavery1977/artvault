import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_fields.dart';
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
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authProvider.notifier)
        .register(_name.text, _email.text, _password.text);
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
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
            children: [
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
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _confirm,
                label: 'Confirm password',
                icon: Icons.lock_outline,
                obscureText: _obscure,
                validator: (v) => Validators.passwordConfirm(v, _password.text),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Switch(value: _obscure, onChanged: (v) => setState(() => _obscure = v)),
                  const SizedBox(width: AppSpacing.xs),
                  const Text('Show password'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Create Account',
                loading: auth.busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
