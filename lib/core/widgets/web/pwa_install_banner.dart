import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/remote/cloud_backend.dart';
import 'pwa_install_bridge.dart';

/// Banner that offers to install ArtVault as a PWA.
///
/// Unlike a static hint, this only appears once the browser signals the app
/// is installable (Chromium's `beforeinstallprompt`) and tapping *Install*
/// opens the browser's native install dialog via [PwaInstallSupport.promptInstall].
/// Browsers without install support never see the banner.
class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  final PwaInstallSupport _support = PwaInstallSupport.instance;

  StreamSubscription<void>? _installableSub;
  StreamSubscription<void>? _installedSub;
  StreamSubscription<String>? _outcomeSub;
  bool _canInstall = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _installableSub = _support.onInstallable.listen((_) {
      // A fresh event means the user can be prompted again (e.g. after a
      // reload), so a previous dismissal no longer applies.
      if (mounted) setState(() => _canInstall = !_dismissed);
    });
    _installedSub = _support.onInstalled.listen((_) {
      if (mounted) setState(() => _canInstall = false);
    });
    _outcomeSub = _support.onInstallOutcome.listen((outcome) {
      // Native dialog answered — track how the install prompt performed.
      CloudBackend.instance.logEvent('pwa_install_prompt', {
        'outcome': outcome,
      });
    });
  }

  @override
  void dispose() {
    _installableSub?.cancel();
    _installedSub?.cancel();
    _outcomeSub?.cancel();
    super.dispose();
  }

  void _install() {
    // Must stay inside the user gesture — the browser shows its own dialog.
    _support.promptInstall();
    setState(() {
      _canInstall = false;
      _dismissed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_canInstall || _dismissed) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSlide(
      offset: const Offset(0, 0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    scheme.primaryContainer.withValues(alpha: 0.15),
                    scheme.tertiaryContainer.withValues(alpha: 0.10),
                  ]
                : [
                    scheme.primaryContainer.withValues(alpha: 0.3),
                    scheme.tertiaryContainer.withValues(alpha: 0.2),
                  ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.install_mobile_rounded, size: 22, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Install ArtVault',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add ArtVault to your device for instant, offline access',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _install,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Install'),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => setState(() => _dismissed = true),
              icon: Icon(
                Icons.close,
                size: 16,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
