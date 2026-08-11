import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/qr_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/art_image.dart';
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

    // Not in this vault — preview what the code carries, then let the user
    // add a reference copy so the code works across devices/accounts.
    if (!mounted) return;
    final add = await _showPreview(payload);

    if (!mounted) return;
    if (add == true) {
      final now = DateTime.now();
      final title = payload.title?.trim().isNotEmpty == true
          ? payload.title!.trim()
          : null;
      final artist = payload.artistName?.trim().isNotEmpty == true
          ? payload.artistName!.trim()
          : null;
      final painting = await PaintingRepository.instance.save(
        Painting(
          id: payload.paintingId,
          title: title ?? 'Scanned artwork',
          artistId: '',
          artistName: artist ?? '',
          price: payload.price,
          currency: payload.currency ?? 'USD',
          description: payload.description ?? '',
          coverImageUrl: payload.imageUrl ?? '',
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

  /// Preview dialog for a code pointing at an artwork not in this vault.
  /// Legacy codes (older builds, no metadata) get an explanatory variant
  /// that suggests re-generating the code.
  Future<bool?> _showPreview(QrPayload payload) {
    final title = payload.title?.trim().isNotEmpty == true
        ? payload.title!.trim()
        : null;

    return showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final legacy = payload.isLegacy;

        final Widget content;
        if (legacy) {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.qr_code_2, size: 32, color: scheme.primary),
              const SizedBox(height: AppSpacing.sm),
              Text('Older QR code', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This code was created by an older version of ArtVault and '
                'only carries an internal id, so no artwork details are '
                'available.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Tip: open the painting in the app it was created '
                        'from and share a fresh QR code — it will include '
                        'the title, artist, price and photo.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (payload.imageUrl != null)
                ArtImage(
                  url: payload.imageUrl,
                  width: double.infinity,
                  height: 160,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 96,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    size: 32,
                    color: scheme.primary.withValues(alpha: 0.4),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              if (title != null)
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (payload.artistName?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  payload.artistName!.trim(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (payload.price != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    Formatters.money(
                      payload.price!,
                      currency: payload.currency ?? 'USD',
                    ),
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              if (payload.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  payload.description!.trim(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This artwork is not in your vault yet. Add it so you can '
                'view and manage it here?',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }

        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add to vault'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
