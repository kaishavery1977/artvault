import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/qr_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/painting_repository.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final payload = QrService.parsePayload(raw);
      if (payload == null) continue;
      _resolve(payload);
      return;
    }
  }

  /// Resolves a scanned code: exact id first, then title/artist fallback
  /// (the id is device-local, so the same artwork scanned from another
  /// device carries a different id), then offer to add it to this vault.
  Future<void> _resolve(QrPayload payload) async {
    _handled = true;
    await _controller.stop();

    Painting? painting = PaintingRepository.instance.get(payload.paintingId);
    painting ??= _matchByMetadata(payload);
    if (painting != null && mounted) {
      context.push('/painting/${painting.id}');
      return;
    }

    // Not in this vault — let the user add a reference copy so the code
    // works across devices/accounts.
    final title = payload.title?.trim().isNotEmpty == true
        ? payload.title!.trim()
        : null;
    final artist = payload.artistName?.trim().isNotEmpty == true
        ? payload.artistName!.trim()
        : null;

    if (!mounted) return;
    final add = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.qr_code_2, size: 32),
        title: Text(title ?? 'Artwork not in this vault'),
        content: Text(
          title == null
              ? 'This QR code points to an artwork that is not in your vault yet. '
                    'Add it so you can view and manage it here?'
              : '“$title”${artist != null ? ' by $artist' : ''} is not in your '
                    'vault yet. Add it so you can view and manage it here?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add to vault'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (add == true) {
      final now = DateTime.now();
      final painting = await PaintingRepository.instance.save(
        Painting(
          id: payload.paintingId,
          title: title ?? 'Scanned artwork',
          artistId: '',
          artistName: artist ?? '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (mounted) {
        context.push('/painting/${painting.id}');
      }
      return;
    }

    // Cancelled — resume scanning.
    _handled = false;
    await _controller.start();
  }

  /// Finds a local painting whose title/artist matches the metadata embedded
  /// in the code (used when the id differs because it came from another
  /// device).
  Painting? _matchByMetadata(QrPayload payload) {
    final title = payload.title?.trim().toLowerCase();
    final artist = payload.artistName?.trim().toLowerCase();
    if (title == null && artist == null) return null;

    final all = PaintingRepository.instance.readActive();
    Painting? best;
    for (final p in all) {
      final sameTitle =
          title != null && p.title.trim().toLowerCase().contains(title);
      final sameArtist =
          artist != null && p.artistName.trim().toLowerCase().contains(artist);
      if (sameTitle && sameArtist) return p; // strongest match
      if (sameTitle && best == null) best = p;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a QR code')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: MobileScanner(controller: _controller, onDetect: _onDetect),
          ),
          Positioned(
            bottom: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code_2, color: scheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Point the camera at an ArtVault QR code to open its artwork.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Toggle torch',
                    icon: const Icon(Icons.flashlight_on_outlined),
                    onPressed: () => _controller.toggleTorch(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
