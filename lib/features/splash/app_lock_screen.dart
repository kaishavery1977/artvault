import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/biometric_service.dart';
import '../../core/widgets/success_overlay.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/face_scan_screen.dart';

/// Cold-start lock gate shown when App Lock is enabled.
///
/// Offers distinct unlock methods — fingerprint (strong biometrics), Face
/// lock (weak biometrics / genuine face scan) and a 4-digit passcode — so the
/// vault stays reachable even when one method fails or is unavailable.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  bool _checking = true;

  /// True while the success confirmation is playing before navigating home.
  bool _unlocked = false;
  String _unlockMessage = 'Unlocked!';
  late final AnimationController _unlock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  // Which unlock methods are switched on (settings) and actually available.
  bool _fingerprintOn = false;
  bool _fingerprintAvailable = false;
  bool _faceOn = false;
  bool _faceAvailable = false;
  bool _passcodeSet = false;

  bool _pinMode = false;
  String _pin = '';
  String _status = 'Checking security…';

  bool get _fingerprintMethod => _fingerprintOn && _fingerprintAvailable;
  bool get _faceMethod => _faceOn && _faceAvailable;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final fpOn = await AuthRepository.instance.biometricEnabled;
    final fpAvail = await BiometricService.instance.hasFingerprint;
    final faceOn = await AuthRepository.instance.faceLockEnabled;
    final faceAvail = await BiometricService.instance.hasFaceId;
    final passcode = await AuthRepository.instance.passcodeSet;
    if (!mounted) return;
    setState(() {
      _fingerprintOn = fpOn;
      _fingerprintAvailable = fpAvail;
      _faceOn = faceOn;
      _faceAvailable = faceAvail;
      _passcodeSet = passcode;
      _checking = false;
      _status = '';
    });
    if (_fingerprintMethod) {
      _verifyFingerprint();
    } else if (_faceMethod) {
      _verifyFace();
    } else if (!_passcodeSet) {
      setState(() => _status = 'No unlock method is set up.');
    }
    // Only a passcode exists → the PIN pad is shown directly below.
  }

  Future<void> _verifyFingerprint() async {
    setState(() {
      _checking = true;
      _status = '';
    });
    final ok = await BiometricService.instance.authenticateFingerprint();
    if (!mounted) return;
    if (ok) {
      await _showUnlockSuccess(message: 'Fingerprint accepted — unlocking…');
      return;
    }
    setState(() {
      _checking = false;
      _status = 'Fingerprint not recognised. Try again.';
    });
  }

  Future<void> _verifyFace() async {
    setState(() {
      _checking = true;
      _status = '';
    });
    final repo = AuthRepository.instance;
    final embedding = await repo.faceEmbedding;
    if (!mounted) return;
    if (embedding == null || embedding.isEmpty) {
      // No enrollment yet (e.g. face lock enabled before identity matching
      // existed) — run enrollment first, then unlock.
      final emb = await context.push<List<double>>(
        '/face-scan',
        extra: const FaceScanScreen(mode: FaceScanMode.enroll),
      );
      if (!mounted) return;
      if (emb == null || emb.isEmpty) {
        setState(() {
          _checking = false;
          _status = 'Face not set up. Try again.';
        });
        return;
      }
      try {
        await repo.saveFaceEmbedding(emb);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _status = 'Could not save face: $e';
        });
        return;
      }
      // Confirm the write actually landed before unlocking.
      final saved = await repo.faceEmbedding;
      if (!mounted) return;
      if (saved == null || saved.isEmpty) {
        setState(() {
          _checking = false;
          _status = 'Save failed. Please try again.';
        });
        return;
      }
      await _showUnlockSuccess(message: 'Face saved ✓');
      return;
    }
    // Verify: the camera feed must MATCH the enrolled face.
    final ok = await context.push<bool>(
      '/face-scan',
      extra: FaceScanScreen(
        mode: FaceScanMode.verify,
        enrolledEmbedding: embedding,
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      await _showUnlockSuccess(message: 'Face recognized — unlocking…');
    } else {
      setState(() {
        _checking = false;
        _status = 'Face not recognised. Try again.';
      });
    }
  }

  Future<void> _usePasscode() async {
    await BiometricService.instance.stop();
    if (!mounted) return;
    setState(() {
      _pinMode = true;
      _pin = '';
      _status = '';
    });
  }

  void _onDigit(String digit) {
    if (_checking || _pin.length >= AppConstants.kPasscodeLength) return;
    HapticFeedback.selectionClick();
    final next = _pin + digit;
    setState(() => _pin = next);
    if (next.length == AppConstants.kPasscodeLength) _checkPin(next);
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _checkPin(String pin) async {
    setState(() => _checking = true);
    final ok = await AuthRepository.instance.verifyPasscode(pin);
    if (!mounted) return;
    if (ok) {
      await _showUnlockSuccess(message: 'Passcode accepted — unlocking…');
      return;
    }
    setState(() {
      _checking = false;
      _pin = '';
      _status = 'Incorrect passcode. Try again.';
    });
  }

  /// Plays the shared success confirmation for every unlock method, then
  /// navigates home once it has been shown.
  Future<void> _showUnlockSuccess({String message = 'Unlocked!'}) async {
    await BiometricService.instance.stop();
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() {
      _checking = true;
      _unlocked = true;
      _unlockMessage = message;
    });
    _unlock.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1150));
    if (!mounted) return;
    context.go('/home');
  }

  @override
  void dispose() {
    _unlock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    // The PIN pad is shown when the user opted into it, or when it's the only
    // unlock method available.
    final showPinPad =
        _pinMode || (!_fingerprintMethod && !_faceMethod && _passcodeSet);

    return Scaffold(
      // Transparent so the ambient gradient shows behind the lock screen.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.secondary, AppColors.accent],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 44,
                        color: Colors.white,
                      ),
                    ).animate().scale(
                      begin: const Offset(0.6, 0.6),
                      curve: Curves.easeOutBack,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'ArtVault is locked',
                      style: AppTheme.display(
                        context,
                        size: 26,
                      ).copyWith(color: fg),
                    ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      showPinPad
                          ? 'Enter your passcode to open your private gallery'
                          : 'Unlock to open your private gallery',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (showPinPad)
                      _PinPad(
                        length: AppConstants.kPasscodeLength,
                        entered: _pin.length,
                        enabled: !_checking,
                        onDigit: _onDigit,
                        onBackspace: _onBackspace,
                      )
                    else ...[
                      if (_faceMethod) ...[
                        _UnlockButton(
                          icon: Icons.face_retouching_natural,
                          label: 'Unlock with Face lock',
                          checking: _checking,
                          onPressed: _verifyFace,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (_fingerprintMethod) ...[
                        _UnlockButton(
                          icon: Icons.fingerprint,
                          label: 'Unlock with Fingerprint',
                          checking: _checking,
                          onPressed: _verifyFingerprint,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (_passcodeSet)
                        TextButton(
                          onPressed: _checking ? null : _usePasscode,
                          child: const Text('Use passcode'),
                        ),
                    ],
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _status,
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    TextButton(
                      onPressed: () async {
                        await AuthRepository.instance.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      child: const Text('Sign out instead'),
                    ),
                  ],
                ),
              ),
            ),
            // Animated confirmation shared with every other unlock method.
            if (_unlocked)
              SuccessCheckOverlay(
                animation: _unlock,
                message: _unlockMessage,
                subtitle: 'Welcome back to your gallery',
              ),
          ],
        ),
      ),
    );
  }
}

class _UnlockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool checking;
  final VoidCallback onPressed;

  const _UnlockButton({
    required this.icon,
    required this.label,
    required this.checking,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: FilledButton.icon(
        onPressed: checking ? null : onPressed,
        icon: checking
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Icon(icon),
        label: Text(checking ? 'Verifying…' : label),
      ),
    );
  }
}

/// Minimal on-screen numeric keypad with progress dots for passcode entry.
class _PinPad extends StatelessWidget {
  final int length;
  final int entered;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _PinPad({
    required this.length,
    required this.entered,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(length, (i) {
            return Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < entered ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: i < entered
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.4),
                  width: 1.6,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final digit in row)
                _Key(
                  label: digit,
                  enabled: enabled,
                  onPressed: () => onDigit(digit),
                ),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 72),
            _Key(label: '0', enabled: enabled, onPressed: () => onDigit('0')),
            _Key(
              label: '⌫',
              enabled: enabled && entered > 0,
              onPressed: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _Key({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(5),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 72,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Glass key: translucent fill + hairline border. Decoration only.
            color: scheme.surface.withValues(
              alpha: enabled ? (isDark ? 0.55 : 0.75) : 0.25,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: enabled ? 0.07 : 0.03),
              width: 0.6,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: enabled ? 1 : 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
