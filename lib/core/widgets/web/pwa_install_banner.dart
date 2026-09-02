import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Shows a subtle banner prompting the user to install ArtVault as a PWA.
/// Uses the browser's native install prompt when available.
class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _dismissed = false;
  bool _canInstall = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    // On web, show the install prompt after a brief delay.
    // The browser's native beforeinstallprompt event requires JS interop;
    // for now we show a static hint that the app supports installation.
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_dismissed) {
        setState(() => _canInstall = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_canInstall || _dismissed) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSlide(
      offset: const Offset(0, 0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.install_mobile_rounded,
              size: 22,
              color: scheme.primary,
            ),
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
                    'Use your browser\'s install button to add ArtVault to your home screen',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
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
