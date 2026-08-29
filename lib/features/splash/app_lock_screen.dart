import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/biometric_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/success_overlay.dart';
import '../../core/providers/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/face_scan_screen.dart';


/// Cold-start lock gate shown when App Lock is enabled.
///
/// Offers distinct unlock methods — fingerprint (strong biometrics), Face
/// lock (weak biometrics / genuine face scan) and a 4-digit passcode — so the
/// vault stays reachable even when one method fails or is unavailable.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen>
    with SingleTickerProviderStateMixin {
  bool _checking = true;

  /// True while the success confirmation is playing before navigating home.
  bool _unlocked = false;
  String _unlockMessage = 'Unlocked!';
  late final AnimationController _unlock;

  @override
  void initState() {
    super.initState();
    // Created eagerly (not `late` at the field): a `late final` initializer
    // would otherwise run on first access — which, when the user signs out
    // without unlocking, happens inside dispose() and builds a Ticker on a
    // deactivated element (crash). Eager creation keeps it in the live tree.
    _unlock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _setup();
  }

  // Which unlock methods are switched on (settings) and actually available.
  bool _fingerprintOn = false;
  bool _fingerprintAvailable = false;
  bool _faceOn = false;
  bool _faceAvailable = false;
  bool _passcodeSet = false;

  bool _pinMode = false;
  String _pin = '';
  String _status = 'Checking security…';

  /// True while the on-screen status is an error (rendered in the error
  /// color rather than muted, and the PIN dots turn red).
  bool _statusError = false;

  /// Active passcode lockout (persisted across restarts). While non-zero
  /// the PIN pad is disabled and a countdown is shown.
  Duration _lockoutRemaining = Duration.zero;
  Timer? _lockTimer;

  /// Increments on every wrong passcode so the pad shakes in place.
  int _shakeTick = 0;

  bool get _fingerprintMethod => _fingerprintOn && _fingerprintAvailable;
  bool get _faceMethod => _faceOn && _faceAvailable;

  Future<void> _setup() async {
    final fpOn = await AuthRepository.instance.biometricEnabled;
    final fpAvail = await BiometricService.instance.hasFingerprint;
    final faceOn = await AuthRepository.instance.faceLockEnabled;
    final faceAvail = await BiometricService.instance.hasFaceId;
    final passcode = await AuthRepository.instance.passcodeSet;
    // A lockout set before a restart must still throttle the pad.
    final lockRemaining = await AuthRepository.instance.passcodeLockRemaining();
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
    if (lockRemaining > Duration.zero) {
      _startLockout(lockRemaining);
    } else if (_fingerprintMethod) {
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
      _statusError = false;
    });
  }

  void _onDigit(String digit) {
    if (_checking ||
        _lockoutRemaining > Duration.zero ||
        _pin.length >= AppConstants.kPasscodeLength) {
      return;
    }
    HapticFeedback.selectionClick();
    // A fresh digit after a wrong attempt clears the error state (message
    // and red dots) so the user retypes against a clean pad.
    if (_statusError) {
      setState(() {
        _statusError = false;
        _status = '';
      });
    }
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
      await AuthRepository.instance.resetPasscodeAttempts();
      await _showUnlockSuccess(message: 'Passcode accepted — unlocking…');
      return;
    }
    HapticFeedback.vibrate();
    // Throttle brute-force attempts: wrong tries register a lockout that
    // grows with every further failure and survives app restarts.
    final lockout = await AuthRepository.instance.registerPasscodeFailure();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _pin = '';
      _statusError = true;
      _shakeTick++;
    });
    if (lockout > Duration.zero) {
      _startLockout(lockout);
    } else {
      setState(() => _status = 'Incorrect passcode. Try again.');
    }
  }

  /// Disables the PIN pad and shows a live countdown for [duration].
  void _startLockout(Duration duration) {
    _lockTimer?.cancel();
    setState(() {
      _lockoutRemaining = duration;
      _status = 'Too many attempts — try again in ${_formatLock(duration)}';
    });
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _lockoutRemaining - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        _lockTimer?.cancel();
        setState(() {
          _lockoutRemaining = Duration.zero;
          _status = '';
          _statusError = false;
        });
      } else {
        setState(() {
          _lockoutRemaining = remaining;
          _status =
              'Too many attempts — try again in ${_formatLock(remaining)}';
        });
      }
    });
  }

  static String _formatLock(Duration d) {
    final s = d.inSeconds % 60;
    return d.inMinutes > 0
        ? '${d.inMinutes}:${s.toString().padLeft(2, '0')}'
        : '${s}s';
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
      _statusError = false;
    });
    _unlock.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1150));
    if (!mounted) return;
    context.go('/home');
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
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
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.secondary.withValues(alpha: 0.9),
                                AppColors.accent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        )
                        .animate(
                          onPlay: (c) => MediaQuery.disableAnimationsOf(context)
                              ? c.stop()
                              : null,
                        )
                        .scale(
                          begin: const Offset(0.6, 0.6),
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                          'ArtVault',
                          style: AppTheme.display(
                            context,
                            size: 30,
                          ).copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        )
                        .animate(
                          onPlay: (c) => MediaQuery.disableAnimationsOf(context)
                              ? c.stop()
                              : null,
                        )
                        .fadeIn(duration: 400.ms, delay: 150.ms),
                    const SizedBox(height: 6),
                    Text(
                      showPinPad
                          ? 'Enter passcode to unlock'
                          : 'Verify your identity to unlock',
                      style: TextStyle(
                        fontSize: 14,
                        color: muted,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (showPinPad)
                      ShakeOnError(
                        tick: _shakeTick,
                        child: _PinPad(
                          length: AppConstants.kPasscodeLength,
                          entered: _pin.length,
                          error: _statusError,
                          enabled:
                              !_checking && _lockoutRemaining == Duration.zero,
                          onDigit: _onDigit,
                          onBackspace: _onBackspace,
                        ),
                      )
                    else ...[
                      if (_faceMethod) ...[
                        _BiometricButton(
                          icon: Icons.face_retouching_natural,
                          label: 'Face lock',
                          checking: _checking,
                          onPressed: _verifyFace,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (_fingerprintMethod) ...[
                        _BiometricButton(
                          icon: Icons.fingerprint,
                          label: 'Fingerprint',
                          checking: _checking,
                          onPressed: _verifyFingerprint,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (_passcodeSet)
                        TextButton(
                          onPressed: _checking ? null : _usePasscode,
                          style: TextButton.styleFrom(
                            foregroundColor: muted,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Use passcode',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _status,
                          key: ValueKey(_status),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: _statusError
                                ? Theme.of(context).colorScheme.error
                                : muted,
                            fontWeight: _statusError
                                ? FontWeight.w600
                                : FontWeight.w400,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    TextButton(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).signOut();
                        if (context.mounted) context.go('/login');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: muted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'Sign out',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: muted,
                        ),
                      ),
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

/// Circular biometric button with an icon above a subtle label.
/// Follows iOS-style unlock buttons: glass circle + thin icon + label.
class _BiometricButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool checking;
  final VoidCallback onPressed;

  const _BiometricButton({
    required this.icon,
    required this.label,
    required this.checking,
    required this.onPressed,
  });

  @override
  State<_BiometricButton> createState() => _BiometricButtonState();
}

class _BiometricButtonState extends State<_BiometricButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return GestureDetector(
      onTapDown: widget.checking
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.checking
          ? null
          : (_) {
              setState(() => _pressed = false);
              HapticFeedback.mediumImpact();
              widget.onPressed();
            },
      onTapCancel: widget.checking
          ? null
          : () => setState(() => _pressed = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _pressed
                  ? scheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                  : scheme.surface.withValues(
                      alpha: isDark ? 0.5 : 0.65,
                    ),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: widget.checking
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : Icon(
                    widget.icon,
                    size: 30,
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.checking ? 'Verifying…' : widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: muted,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Professional PIN pad with circular keys and animated dot indicators.
///
/// Follows iOS-style spacing, haptic feedback, and smooth color transitions
/// for a polished, high-end unlock experience.
class _PinPad extends StatefulWidget {
  final int length;
  final int entered;
  final bool error;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _PinPad({
    required this.length,
    required this.entered,
    required this.error,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  State<_PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<_PinPad> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  int _previousEntered = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(covariant _PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pulse the newest dot when a digit is added.
    if (widget.entered > _previousEntered &&
        widget.entered <= widget.length) {
      _pulseController.forward(from: 0);
    }
    _previousEntered = widget.entered;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = widget.error ? scheme.error : scheme.primary;
    final mutedColor = scheme.onSurface.withValues(alpha: isDark ? 0.25 : 0.2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Dot indicators ──
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.length, (i) {
                final filled = i < widget.entered;
                // Only pulse the last filled dot.
                final pulsing = filled && i == widget.entered - 1;
                final scale = pulsing ? _pulseAnimation.value : 1.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Transform.scale(
                    scale: scale,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? dotColor : Colors.transparent,
                        border: Border.all(
                          color: filled ? dotColor : mutedColor,
                          width: 1.8,
                        ),
                        boxShadow: filled
                            ? [
                                BoxShadow(
                                  color: dotColor.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 44),
        // ── Number grid ──
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final digit in row)
                  _Key(
                    label: digit,
                    enabled: widget.enabled,
                    onPressed: () => widget.onDigit(digit),
                  ),
              ],
            ),
          ),
        // ── Bottom row: empty, 0, backspace ──
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 80),
            _Key(
              label: '0',
              enabled: widget.enabled,
              onPressed: () => widget.onDigit('0'),
            ),
            _Key(
              label: '⌫',
              enabled: widget.enabled && widget.entered > 0,
              onPressed: widget.onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

/// Circular glass key with press feedback — follows the iOS numeric keypad
/// style with subtle scale and opacity transitions.
class _Key extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _Key({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveEnabled = widget.enabled && !_pressed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                HapticFeedback.lightImpact();
                widget.onPressed();
              }
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _pressed = false)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed
                ? scheme.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                : scheme.surface.withValues(
                    alpha: effectiveEnabled ? (isDark ? 0.45 : 0.7) : 0.2,
                  ),
            border: Border.all(
              color: _pressed
                  ? scheme.primary.withValues(alpha: 0.4)
                  : scheme.onSurface.withValues(
                      alpha: effectiveEnabled ? 0.08 : 0.03,
                    ),
              width: 0.8,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 100),
            style: TextStyle(
              fontSize: widget.label == '⌫' ? 22 : 28,
              fontWeight: FontWeight.w300,
              color: scheme.onSurface.withValues(
                alpha: effectiveEnabled ? 0.9 : 0.25,
              ),
              fontFamily: widget.label == '⌫' ? null : '.SF Pro Display',
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
