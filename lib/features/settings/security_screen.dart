import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/biometric_service.dart';
import '../../core/widgets/surfaces.dart';
import '../auth/face_scan_screen.dart';
import '../../core/providers/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/remote/cloud_backend.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _biometric = false;
  bool _available = false;
  bool _fingerprintAvailable = false;
  bool _faceLock = false;
  bool _faceAvailable = false;
  bool _appLock = false;
  bool _passcodeSet = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AuthRepository.instance.biometricEnabled;
    final available = await BiometricService.instance.isAvailable;
    final fingerprintAvailable = await BiometricService.instance.hasFingerprint;
    final faceEnabled = await AuthRepository.instance.faceLockEnabled;
    final faceAvailable = await BiometricService.instance.hasFaceId;
    final appLock = SettingsRepository.instance.appLockEnabled;
    final passcodeSet = await AuthRepository.instance.passcodeSet;
    if (mounted) {
      setState(() {
        _biometric = enabled;
        _available = available;
        _fingerprintAvailable = fingerprintAvailable;
        _faceLock = faceEnabled;
        _faceAvailable = faceAvailable;
        _appLock = appLock;
        _passcodeSet = passcodeSet;
        _loading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Fingerprint-only prompt (BIOMETRIC_STRONG) — never the device PIN.
      final ok = await AuthRepository.instance.verifyFingerprint();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fingerprint verification failed')),
          );
        }
        return;
      }
    }
    await AuthRepository.instance.setBiometricEnabled(value);
    if (mounted) setState(() => _biometric = value);
  }

  Future<void> _toggleFaceLock(bool value) async {
    if (value) {
      // Enroll: capture the owner's face and store its embedding.
      final emb = await context.push<List<double>>(
        '/face-scan',
        extra: const FaceScanScreen(mode: FaceScanMode.enroll),
      );
      if (!mounted) return;
      if (emb == null || emb.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face enrollment cancelled')),
        );
        return;
      }
      await AuthRepository.instance.saveFaceEmbedding(emb);
      if (!mounted) return;
      // Confirm the write actually landed before enabling the setting — a
      // failed save would otherwise route the user to an unlockable lock.
      final saved = await AuthRepository.instance.faceEmbedding;
      if (!mounted) return;
      if (saved == null || saved.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your face. Please try again.'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face lock set up. Only your face can unlock.'),
        ),
      );
    }
    await AuthRepository.instance.setFaceLockEnabled(value);
    if (mounted) setState(() => _faceLock = value);
  }

  Future<void> _togglePasscode(bool value) async {
    if (value) {
      // Enabling requires the user to pick a new passcode.
      final pin = await _showSetPasscodeDialog();
      if (pin == null) return;
      await AuthRepository.instance.setPasscode(pin);
    } else {
      // Disabling requires re-entering the current passcode.
      final ok = await _showVerifyPasscodeDialog('Enter your current passcode');
      if (!ok) return;
      await AuthRepository.instance.clearPasscode();
    }
    if (mounted) setState(() => _passcodeSet = value);
  }

  Future<void> _changePasscode() async {
    final ok = await _showVerifyPasscodeDialog('Enter your current passcode');
    if (!ok) return;
    final pin = await _showSetPasscodeDialog();
    if (pin == null) return;
    await AuthRepository.instance.setPasscode(pin);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passcode updated')));
    }
  }

  Future<String?> _showSetPasscodeDialog() async {
    final pin = TextEditingController();
    final confirm = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set passcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a ${AppConstants.kPasscodeLength}-digit passcode to unlock '
              'ArtVault when biometrics are unavailable or fail.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: pin,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: AppConstants.kPasscodeLength,
              decoration: const InputDecoration(
                labelText: 'Passcode',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: confirm,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: AppConstants.kPasscodeLength,
              decoration: const InputDecoration(
                labelText: 'Confirm passcode',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final digitsOnly = RegExp(r'^[0-9]+$');
              if (pin.text.length != AppConstants.kPasscodeLength ||
                  !digitsOnly.hasMatch(pin.text) ||
                  pin.text != confirm.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passcodes must be 4 digits and match'),
                  ),
                );
                return;
              }
              Navigator.pop(context, pin.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    pin.dispose();
    confirm.dispose();
    return result;
  }

  Future<bool> _showVerifyPasscodeDialog(String title) async {
    final pin = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: pin,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: AppConstants.kPasscodeLength,
          decoration: const InputDecoration(
            labelText: 'Passcode',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final valid = await AuthRepository.instance.verifyPasscode(
                pin.text,
              );
              if (context.mounted) Navigator.pop(context, valid);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    pin.dispose();
    return ok ?? false;
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value && !_available && !_passcodeSet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No unlock method available on this device. Set a passcode first.',
            ),
          ),
        );
      }
      return;
    }
    await SettingsRepository.instance.setAppLockEnabled(value);
    if (mounted) setState(() => _appLock = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final signedIn = auth.user?.email.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App lock',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Row(
                  icon: Icons.lock_outline,
                  title: 'Lock the app on launch',
                  subtitle: 'Show a lock screen before ArtVault opens',
                  trailing: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(value: _appLock, onChanged: _toggleAppLock),
                ),
                const Divider(height: 16),
                _Row(
                  icon: Icons.face_retouching_natural,
                  title: 'Unlock with Face lock',
                  subtitle: _faceAvailable
                      ? 'Scan your face with the camera to unlock'
                      : 'No camera available for face unlock',
                  trailing: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _faceLock,
                          onChanged: _faceAvailable ? _toggleFaceLock : null,
                        ),
                  onTap: _faceAvailable
                      ? null
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Face Unlock is not set up on this device. '
                              'Enable Face Unlock in your phone settings first.',
                            ),
                          ),
                        ),
                ),
                const Divider(height: 16),
                _Row(
                  icon: Icons.fingerprint,
                  title: 'Unlock with Fingerprint',
                  subtitle: _fingerprintAvailable
                      ? 'Use the fingerprint sensor to unlock'
                      : 'Not set up — add a fingerprint in your device settings',
                  trailing: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _biometric,
                          onChanged: _fingerprintAvailable
                              ? _toggleBiometric
                              : null,
                        ),
                  onTap: _fingerprintAvailable
                      ? null
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No fingerprint is set up on this device. '
                              'Add one in your phone settings first.',
                            ),
                          ),
                        ),
                ),
                const Divider(height: 16),
                _Row(
                  icon: Icons.pin_outlined,
                  title: 'Passcode lock',
                  subtitle: _passcodeSet
                      ? 'Unlock with a ${AppConstants.kPasscodeLength}-digit passcode when biometrics fail'
                      : 'Set a ${AppConstants.kPasscodeLength}-digit passcode to unlock the vault',
                  trailing: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(value: _passcodeSet, onChanged: _togglePasscode),
                  onTap: _passcodeSet ? _changePasscode : null,
                ),
                if (_available ||
                    _faceAvailable ||
                    _fingerprintAvailable ||
                    _passcodeSet)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'Fingerprint uses the device sensor; Face lock scans with the front camera when the phone does not expose Face Unlock to apps.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Row(
                  icon: Icons.lock_reset,
                  title: 'Change password',
                  subtitle: signedIn
                      ? 'Set a new password right here, no email needed'
                      : 'Update your ArtVault sign-in password',
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: signedIn ? _changePasswordInApp : _notSignedIn,
                ),
                const Divider(height: 16),
                _Row(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Send reset email',
                  subtitle: 'Get a reset link by email if you forgot it',
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    if (!CloudBackend.instance.isReady) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cloud is not connected. Sign in with an email account to reset your password.',
                          ),
                        ),
                      );
                      return;
                    }
                    final email = await _showResetDialog(
                      auth.user?.email ?? '',
                    );
                    if (email == null || email.isEmpty) return;
                    final ok = await ref
                        .read(authProvider.notifier)
                        .forgotPassword(email);
                    if (!context.mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Reset link sent to $email. Check spam/junk if it does not arrive in a few minutes.',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            auth.error ??
                                'Could not send the reset email. Check the address and try again.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Your data is stored locally on this device and encrypted with the platform keychain. '
            'When cloud sync is enabled, your vault is protected with Firebase Authentication.',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _notSignedIn() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to change your password')),
    );
  }

  /// In-app password change for signed-in users — current + new password,
  /// no reset email required. Re-authenticates with Firebase first so the
  /// change can't be made by someone who borrowed the device.
  Future<void> _changePasswordInApp() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    String? errorText;
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Change password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your current password, then choose a new one. '
                  'No email is needed for signed-in users.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: current,
                  autofocus: true,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (current.text.isEmpty ||
                      next.text.isEmpty ||
                      confirm.text.isEmpty) {
                    setDialogState(() {
                      errorText = 'Fill in all three fields';
                    });
                    return;
                  }
                  if (next.text.length < 6) {
                    setDialogState(() {
                      errorText = 'New password must be at least 6 characters';
                    });
                    return;
                  }
                  if (next.text != confirm.text) {
                    setDialogState(() {
                      errorText = 'New passwords do not match';
                    });
                    return;
                  }
                  setDialogState(() => errorText = null);
                  try {
                    await AuthRepository.instance.changePassword(
                      currentPassword: current.text,
                      newPassword: next.text,
                    );
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  } catch (e) {
                    setDialogState(() {
                      errorText = e
                          .toString()
                          .replaceFirst('Exception: ', '')
                          .replaceFirst('firebase_auth/', '');
                    });
                  }
                },
                child: const Text('Update password'),
              ),
            ],
          ),
        ),
      );
      if (result == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password changed')));
      }
    } finally {
      current.dispose();
      next.dispose();
      confirm.dispose();
    }
  }

  Future<String?> _showResetDialog([String initial = '']) async {
    final controller = TextEditingController(text: initial);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    controller.dispose();
    return email;
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
