import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/painting.dart';

/// Print-friendly painting report view for web.
/// Clean layout optimized for Ctrl+P printing.
class PrintReportView extends ConsumerWidget {
  final String paintingId;
  const PrintReportView({super.key, required this.paintingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paintingsAsync = ref.watch(paintingsProvider);
    final paintings = paintingsAsync.valueOrNull ?? const <Painting>[];
    final painting = paintings.where((p) => p.id == paintingId).firstOrNull;

    if (painting == null) {
      return const Center(child: Text('Painting not found'));
    }

    final currency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.secondary, AppColors.accent],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.palette_rounded, size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ArtVault',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                        Text(
                          'Art Collection Report',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Generated ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Title
                Text(
                  painting.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                if (painting.artistName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'by ${painting.artistName}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 24),

                // Image placeholder
                if (painting.coverImagePath.isNotEmpty)
                  Container(
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[100],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      painting.coverImagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(Icons.palette_rounded, size: 64, color: Colors.grey[300]),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Metadata table
                _ReportSection(
                  title: 'Details',
                  children: [
                    _ReportRow('Artist', painting.artistName.isNotEmpty ? painting.artistName : '—'),
                    _ReportRow('Medium', painting.medium.isNotEmpty ? painting.medium : '—'),
                    _ReportRow('Style', painting.style.isNotEmpty ? painting.style : '—'),
                    _ReportRow('Category', painting.category.isNotEmpty ? painting.category : '—'),
                    if (painting.width != null || painting.height != null)
                      _ReportRow('Dimensions', '${painting.width ?? '—'} × ${painting.height ?? '—'} ${painting.dimensionUnit}'),
                    if (painting.weight != null)
                      _ReportRow('Weight', '${painting.weight} ${painting.weightUnit}'),
                  ],
                ),
                const SizedBox(height: 16),

                _ReportSection(
                  title: 'Value',
                  children: [
                    _ReportRow('Price', painting.price != null ? Formatters.money(painting.price!, currency: currency) : '—'),
                    if (painting.priceHistory.isNotEmpty)
                      _ReportRow('Price History', '${painting.priceHistory.length} recorded changes'),
                  ],
                ),
                const SizedBox(height: 16),

                if (painting.description.isNotEmpty) ...[
                  _ReportSection(
                    title: 'Description',
                    children: [
                      Text(
                        painting.description,
                        style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (painting.tags.isNotEmpty) ...[
                  _ReportSection(
                    title: 'Tags',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: painting.tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(t, style: TextStyle(fontSize: 12, color: AppColors.accent)),
                        )).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (painting.provenance.isNotEmpty) ...[
                  _ReportSection(
                    title: 'Provenance',
                    children: [
                      for (final entry in painting.provenance)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            entry.toString(),
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Footer
                const Divider(height: 32),
                Center(
                  child: Text(
                    '© ${DateTime.now().year} ArtVault — Crafted by Kais Havery',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _ReportSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReportRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
