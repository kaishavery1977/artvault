import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/biometric_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../auth/face_scan_screen.dart';
import '../../core/providers/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/remote/cloud_backend.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  /// Injectable availability probe (test seam). When null, the real
  /// [BiometricService] is queried.
  final Future<BiometricAvailability> Function()? availabilityProbe;

  const SecurityScreen({super.key, this.availabilityProbe});

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
    final availability = widget.availabilityProbe != null
        ? await widget.availabilityProbe!()
        : await BiometricService.instance.availability;
    final enabled = await AuthRepository.instance.biometricEnabled;
    final faceEnabled = await AuthRepository.instance.faceLockEnabled;
    final appLock = SettingsRepository.instance.appLockEnabled;
    // Secure storage can fail (lockout, plugin hiccup) — never freeze the
    // whole screen on a spinner because of it.
    var passcodeSet = false;
    try {
      passcodeSet = await AuthRepository.instance.passcodeSet;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _biometric = enabled;
        _available = availability.any;
        _fingerprintAvailable = availability.fingerprint;
        _faceLock = faceEnabled;
        _faceAvailable = availability.face;
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
      try {
        await AuthRepository.instance.saveFaceEmbedding(emb);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save your face. Please try again.'),
            ),
          );
        }
        return;
      }
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

  /// Once Face lock is on, tapping the row manages it: re-scan replaces the
  /// stored embedding, or the lock can be removed — so a changed face (new
  /// look, new phone) never strands the user on an unlockable lock.
  Future<void> _showFaceManageSheet() async {
    final action = await showModalBottomSheet<_FaceAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.face_retouching_natural),
              title: const Text('Re-scan face'),
              subtitle: const Text(
                'Replace the face used to unlock ArtVault',
              ),
              onTap: () => Navigator.pop(context, _FaceAction.rescan),
            ),
            ListTile(
              leading: const Icon(Icons.lock_open),
              title: const Text('Remove face lock'),
              subtitle: const Text('Stop unlocking ArtVault with your face'),
              onTap: () => Navigator.pop(context, _FaceAction.remove),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _FaceAction.rescan:
        await _rescanFace();
      case _FaceAction.remove:
        await _toggleFaceLock(false);
    }
  }

  Future<void> _rescanFace() async {
    final emb = await context.push<List<double>>(
      '/face-scan',
      extra: const FaceScanScreen(mode: FaceScanMode.enroll),
    );
    if (!mounted || emb == null || emb.isEmpty) return;
    try {
      await AuthRepository.instance.saveFaceEmbedding(emb);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face updated — your new scan is now active'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the new face. Please try again.'),
          ),
        );
      }
    }
  }

  /// Fingerprints live in the phone's settings; once unlock is enabled the
  /// row offers a self-test and a way to turn it off, and points the user
  /// where to add new prints.
  Future<void> _showFingerprintManageSheet() async {
    final action = await showModalBottomSheet<_FingerprintAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Test fingerprint'),
              subtitle: const Text('Confirm the sensor recognises your print'),
              onTap: () => Navigator.pop(context, _FingerprintAction.test),
            ),
            ListTile(
              leading: const Icon(Icons.lock_open),
              title: const Text('Remove fingerprint unlock'),
              subtitle: const Text('Stop unlocking ArtVault with a fingerprint'),
              onTap: () => Navigator.pop(context, _FingerprintAction.remove),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _FingerprintAction.test:
        await _testFingerprint();
      case _FingerprintAction.remove:
        await _toggleBiometric(false);
    }
  }

  Future<void> _testFingerprint() async {
    final ok = await AuthRepository.instance.verifyFingerprint();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Fingerprint recognized ✓' : 'Fingerprint verification failed',
        ),
      ),
    );
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

  Future<String?> _showSetPasscodeDialog() {
    // The dialog owns its TextEditingControllers in a private StatefulWidget
    // and disposes them only when the route fully unmounts (after the exit
    // transition). Disposing them here, the moment showDialog's future
    // resolves, used to crash the frame: the dialog is still animating out
    // and its TextFields rebuild against disposed controllers, surfacing as
    // "TextEditingController used after being disposed" (and, on-device, a
    // framework `_dependents.isEmpty` assertion as the tree tears down).
    return showDialog<String>(
      context: context,
      builder: (_) => const _SetPasscodeDialog(),
    );
  }

  Future<bool> _showVerifyPasscodeDialog(String title) async {
    // Same ownership pattern as the set-passcode dialog: the controller lives
    // in the dialog's own State so it is disposed only after the route
    // unmounts, never mid-exit-transition.
    return (await showDialog<bool>(
          context: context,
          builder: (_) => _VerifyPasscodeDialog(title: title),
        )) ??
        false;
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
          ...staggerReveal([
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
                  subtitle: _faceLock
                      ? 'On — tap to re-scan or remove your face'
                      : _faceAvailable
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
                      ? (_faceLock ? _showFaceManageSheet : null)
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
                  subtitle: _biometric
                      ? 'On — tap to test it. New prints are added in your phone settings'
                      : _fingerprintAvailable
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
                      ? (_biometric ? _showFingerprintManageSheet : null)
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
          ], context: context),
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

/// Set-passcode dialog. Owns its TextEditingControllers so they are disposed
/// only when the dialog route fully unmounts (after the exit transition) —
/// never while the fields are still animating out.
class _SetPasscodeDialog extends StatefulWidget {
  const _SetPasscodeDialog();

  @override
  State<_SetPasscodeDialog> createState() => _SetPasscodeDialogState();
}

class _SetPasscodeDialogState extends State<_SetPasscodeDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    final digitsOnly = RegExp(r'^[0-9]+$');
    if (_pin.text.length != AppConstants.kPasscodeLength ||
        !digitsOnly.hasMatch(_pin.text) ||
        _pin.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passcodes must be 4 digits and match'),
        ),
      );
      return;
    }
    Navigator.pop(context, _pin.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            controller: _pin,
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
            controller: _confirm,
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
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Verify-current-passcode dialog; same controller-ownership pattern as
/// [_SetPasscodeDialog].
class _VerifyPasscodeDialog extends StatefulWidget {
  final String title;

  const _VerifyPasscodeDialog({required this.title});

  @override
  State<_VerifyPasscodeDialog> createState() => _VerifyPasscodeDialogState();
}

class _VerifyPasscodeDialogState extends State<_VerifyPasscodeDialog> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final valid = await AuthRepository.instance.verifyPasscode(_pin.text);
    if (mounted) Navigator.pop(context, valid);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _pin,
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
        FilledButton(onPressed: _verify, child: const Text('Verify')),
      ],
    );
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

enum _FaceAction { rescan, remove }

enum _FingerprintAction { test, remove }
