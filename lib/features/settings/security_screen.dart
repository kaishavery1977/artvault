import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/biometric_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/utils/validators.dart';
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
  Duration _faceLockRemaining = Duration.zero;
  int _autoLockTimeout = 0; // seconds

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
    final autoLock = SettingsRepository.instance.autoLockTimeoutSeconds;
    // Secure storage can fail (lockout, plugin hiccup) — never freeze the
    // whole screen on a spinner because of it.
    var passcodeSet = false;
    try {
      passcodeSet = await AuthRepository.instance.passcodeSet;
    } catch (_) {}
    var faceLockRemaining = Duration.zero;
    try {
      faceLockRemaining = await AuthRepository.instance.faceLockRemaining();
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
        _faceLockRemaining = faceLockRemaining;
        _autoLockTimeout = autoLock;
        _loading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
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
    // Disabling face lock requires confirmation.
    if (!value) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Face lock?'),
          content: const Text(
            'You will need a passcode or fingerprint to unlock ArtVault.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep enabled'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok != true) return;
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
              subtitle: const Text('Replace the face used to unlock ArtVault'),
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
              subtitle: const Text(
                'Stop unlocking ArtVault with a fingerprint',
              ),
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
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
    // Disabling App Lock requires confirmation to prevent accidental removal.
    if (!value) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disable App Lock?'),
          content: const Text(
            'ArtVault will no longer require authentication to open.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep enabled'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      if (ok != true) return;
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
      appBar: AppBar(title: Text(L10n.t(context, 'Security'))),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SizedBox(height: AppSpacing.sm),
          ...staggerReveal([
            // The device lock options (app launch lock, face, fingerprint,
            // passcode) are phone-only — they read as broken dead switches
            // on the web, so they render there as a single explanatory card.
            if (!kIsWeb) ...[
              GlassCard(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.t(context, 'App lock'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Row(
                      icon: Icons.lock_outline,
                      title: L10n.t(context, 'Lock the app on launch'),
                      subtitle: L10n.t(
                        context,
                        'Show a lock screen before ArtVault opens',
                      ),
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
                      title: L10n.t(context, 'Unlock with Face lock'),
                      subtitle: _faceLockRemaining > Duration.zero
                          ? 'Locked — try again in '
                                '${_faceLockRemaining.inSeconds}s'
                          : _faceLock
                          ? L10n.t(
                              context,
                              'On — tap to re-scan or remove your face',
                            )
                          : _faceAvailable
                          ? L10n.t(
                              context,
                              'Scan your face with the camera to unlock',
                            )
                          : L10n.t(
                              context,
                              'No camera available for face unlock',
                            ),
                      trailing: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Switch(
                              value: _faceLock,
                              onChanged: _faceAvailable
                                  ? _toggleFaceLock
                                  : null,
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
                      title: L10n.t(context, 'Unlock with Fingerprint'),
                      subtitle: _biometric
                          ? L10n.t(
                              context,
                              'On — tap to test it. New prints are added in your phone settings',
                            )
                          : _fingerprintAvailable
                          ? L10n.t(
                              context,
                              'Use the fingerprint sensor to unlock',
                            )
                          : L10n.t(
                              context,
                              'Not set up — add a fingerprint in your device settings',
                            ),
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
                      title: L10n.t(context, 'Passcode lock'),
                      subtitle: _passcodeSet
                          ? 'Unlock with a ${AppConstants.kPasscodeLength}-digit passcode when biometrics fail'
                          : 'Set a ${AppConstants.kPasscodeLength}-digit passcode to unlock the vault',
                      trailing: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Switch(
                              value: _passcodeSet,
                              onChanged: _togglePasscode,
                            ),
                      onTap: _passcodeSet ? _changePasscode : null,
                    ),
                    if (_appLock) ...[
                      const Divider(height: 16),
                      _AutoLockRow(
                        currentSeconds: _autoLockTimeout,
                        onChanged: (seconds) async {
                          await SettingsRepository.instance.setAutoLockTimeout(
                            seconds,
                          );
                          if (mounted) {
                            setState(() => _autoLockTimeout = seconds);
                          }
                        },
                      ),
                    ],
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
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              GlassCard(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.t(context, 'Web security'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      L10n.t(
                        context,
                        'ArtVault for the web protects your vault with your '
                        'ArtVault sign-in (email + password) and Firebase '
                        'Authentication. There is no local app to lock: close '
                        'the tab or sign out to end the session, and use the '
                        'account options below to change your password or send '
                        'a reset email.',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.t(context, 'Account'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Row(
                    icon: Icons.lock_reset,
                    title: L10n.t(context, 'Change password'),
                    subtitle: signedIn
                        ? L10n.t(
                            context,
                            'Set a new password right here, no email needed',
                          )
                        : L10n.t(
                            context,
                            'Update your ArtVault sign-in password',
                          ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: signedIn ? _changePasswordInApp : _notSignedIn,
                  ),
                  const Divider(height: 16),
                  _Row(
                    icon: Icons.mark_email_read_outlined,
                    title: L10n.t(context, 'Send reset email'),
                    subtitle: L10n.t(
                      context,
                      'Get a reset link by email if you forgot it',
                    ),
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
                color: scheme.onSurface.withValues(alpha: 0.6),
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
    // The dialog owns its TextEditingControllers; disposing them here the
    // moment the route pops crashed the frame while it was still animating
    // out (the same bug the passcode dialogs had).
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password changed')));
    }
  }

  Future<String?> _showResetDialog([String initial = '']) {
    // Same owning-dialog pattern — the controller must outlive the exit
    // transition, which is exactly when the old dispose-after-await crashed.
    return showDialog<String>(
      context: context,
      builder: (_) => ResetPasswordDialog(initial: initial),
    );
  }
}

/// Professional two-step passcode setup dialog with PIN-dot entry.
///
/// Step 1: enter new passcode → Step 2: confirm passcode.
/// Shows circular dot indicators and a numeric keypad, matching the
/// lock-screen PIN pad style for visual consistency.
class _SetPasscodeDialog extends StatefulWidget {
  const _SetPasscodeDialog();

  @override
  State<_SetPasscodeDialog> createState() => _SetPasscodeDialogState();
}

class _SetPasscodeDialogState extends State<_SetPasscodeDialog> {
  String _pin = '';

  bool _isConfirmStep = false;
  bool _error = false;
  String _firstPin = '';

  void _onDigit(String digit) {
    if (_pin.length >= AppConstants.kPasscodeLength) return;
    HapticFeedback.selectionClick();
    if (_error) setState(() => _error = false);
    final next = _pin + digit;
    setState(() => _pin = next);
    if (next.length == AppConstants.kPasscodeLength) {
      _onComplete(next);
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onComplete(String pin) {
    if (!_isConfirmStep) {
      // First step done — move to confirm.
      setState(() {
        _firstPin = pin;
        _pin = '';
        _isConfirmStep = true;
      });
    } else {
      // Confirm step — check match.
      if (pin == _firstPin) {
        Navigator.pop(context, pin);
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _error = true;
          _pin = '';
          _isConfirmStep = false;
          _firstPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dotColor = _error ? scheme.error : scheme.primary;
    final mutedColor = scheme.onSurface.withValues(alpha: 0.25);

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      title: Text(
        _isConfirmStep ? 'Confirm passcode' : 'Set passcode',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error
                ? 'Passcodes did not match. Try again.'
                : _isConfirmStep
                ? 'Re-enter your new passcode'
                : 'Choose a ${AppConstants.kPasscodeLength}-digit passcode',
            style: TextStyle(
              fontSize: 13,
              color: _error
                  ? scheme.error
                  : scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          // Dot indicators
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(AppConstants.kPasscodeLength, (i) {
              final filled = i < _pin.length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? dotColor : Colors.transparent,
                    border: Border.all(
                      color: filled ? dotColor : mutedColor,
                      width: 1.5,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          // Numeric keypad
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final d in row)
                    _DialogKey(label: d, onTap: () => _onDigit(d)),
                ],
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 60),
              _DialogKey(label: '0', onTap: () => _onDigit('0')),
              _DialogKey(
                label: '⌫',
                onTap: _pin.isNotEmpty ? _onBackspace : null,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Verify-current-passcode dialog with PIN-dot entry UI.
/// Matches the lock-screen style for visual consistency.
class _VerifyPasscodeDialog extends StatefulWidget {
  final String title;

  const _VerifyPasscodeDialog({required this.title});

  @override
  State<_VerifyPasscodeDialog> createState() => _VerifyPasscodeDialogState();
}

class _VerifyPasscodeDialogState extends State<_VerifyPasscodeDialog> {
  String _pin = '';
  bool _error = false;
  bool _verifying = false;

  void _onDigit(String digit) {
    if (_verifying || _pin.length >= AppConstants.kPasscodeLength) return;
    HapticFeedback.selectionClick();
    if (_error) setState(() => _error = false);
    final next = _pin + digit;
    setState(() => _pin = next);
    if (next.length == AppConstants.kPasscodeLength) _verify(next);
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify(String pin) async {
    setState(() => _verifying = true);
    final valid = await AuthRepository.instance.verifyPasscode(pin);
    if (mounted) {
      if (valid) {
        Navigator.pop(context, true);
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _error = true;
          _verifying = false;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dotColor = _error ? scheme.error : scheme.primary;
    final mutedColor = scheme.onSurface.withValues(alpha: 0.25);

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Incorrect passcode. Try again.',
                style: TextStyle(fontSize: 13, color: scheme.error),
              ),
            ),
          // Dot indicators
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(AppConstants.kPasscodeLength, (i) {
              final filled = i < _pin.length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? dotColor : Colors.transparent,
                    border: Border.all(
                      color: filled ? dotColor : mutedColor,
                      width: 1.5,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          // Numeric keypad
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final d in row)
                    _DialogKey(label: d, onTap: () => _onDigit(d)),
                ],
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 60),
              _DialogKey(label: '0', onTap: () => _onDigit('0')),
              _DialogKey(
                label: '⌫',
                onTap: _pin.isNotEmpty && !_verifying ? _onBackspace : null,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Auto-lock timeout row with a popup menu for selecting the delay.
class _AutoLockRow extends StatelessWidget {
  final int currentSeconds;
  final ValueChanged<int> onChanged;

  const _AutoLockRow({required this.currentSeconds, required this.onChanged});

  static const _options = <(String, int)>[
    ('Immediately', 0),
    ('After 30 seconds', 30),
    ('After 1 minute', 60),
    ('After 5 minutes', 300),
  ];

  String _label(int seconds) {
    for (final (label, s) in _options) {
      if (s == seconds) return label;
    }
    return 'Custom';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.timer_outlined),
      title: const Text('Auto-lock timeout'),
      subtitle: Text(
        _label(currentSeconds),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: PopupMenuButton<int>(
        initialValue: currentSeconds,
        onSelected: onChanged,
        itemBuilder: (context) => [
          for (final (label, seconds) in _options)
            PopupMenuItem(
              value: seconds,
              child: Row(
                children: [
                  if (seconds == currentSeconds)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 12),
                  Text(label),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Text(
            _label(currentSeconds),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular key for passcode dialogs — matches the lock-screen PIN pad
/// style for visual consistency across the passcode flow.
class _DialogKey extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const _DialogKey({required this.label, this.onTap});

  @override
  State<_DialogKey> createState() => _DialogKeyState();
}

class _DialogKeyState extends State<_DialogKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onTap != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed
                ? scheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                : scheme.surface.withValues(alpha: isDark ? 0.4 : 0.6),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: enabled ? 0.08 : 0.03),
              width: 0.6,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: widget.label == '⌫' ? 20 : 24,
              fontWeight: FontWeight.w300,
              color: scheme.onSurface.withValues(alpha: enabled ? 0.85 : 0.25),
            ),
          ),
        ),
      ),
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

/// Change-password dialog. Owns its three TextEditingControllers and disposes
/// them only when the route fully unmounts (after the exit transition) — the
/// old version disposed them in a `finally` the instant `showDialog`
/// resolved, crashing the frame while the fields were still animating out.
///
/// Pops `true` on success, `false` on Cancel. Validation errors (empty
/// fields, short password, mismatch) are shown inline and never reach
/// Firebase; only a fully valid submission calls `AuthRepository`.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty || _next.text.isEmpty || _confirm.text.isEmpty) {
      setState(() => _error = 'Fill in all three fields');
      return;
    }
    if (_next.text.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await AuthRepository.instance.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('firebase_auth/', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.t(context, 'Change password')),
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
            controller: _current,
            autofocus: true,
            obscureText: true,
            maxLength: Validators.maxPasswordLength,
            decoration: InputDecoration(
              labelText: L10n.t(context, 'Current password'),
              errorText: _error,
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _next,
            obscureText: true,
            maxLength: Validators.maxPasswordLength,
            decoration: InputDecoration(
              labelText: L10n.t(context, 'New password'),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _confirm,
            obscureText: true,
            maxLength: Validators.maxPasswordLength,
            decoration: InputDecoration(
              labelText: L10n.t(context, 'Confirm new password'),
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(L10n.t(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(L10n.t(context, 'Update password')),
        ),
      ],
    );
  }
}

/// Reset-password email dialog. Owns its TextEditingController (same
/// rationale as [ChangePasswordDialog]). Pops the trimmed email on Send,
/// `null` on Cancel.
class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key, required this.initial});

  final String initial;

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.t(context, 'Reset password')),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(labelText: L10n.t(context, 'Email')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L10n.t(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(L10n.t(context, 'Send reset link')),
        ),
      ],
    );
  }
}
