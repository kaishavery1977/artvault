import pathlib

p = pathlib.Path(r'lib/features/artists/artist_detail_screen.dart')
c = p.read_text(encoding='utf-8')

# Add stats header after the nationality text and before biography
old_bio = """                          if (artist.nationality.isNotEmpty)
                            Text(
                              artist.nationality,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                        ],
                      ),
                    ),"""

new_bio = """                          if (artist.nationality.isNotEmpty)
                            Text(
                              artist.nationality,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          // Stats row: paintings count + total value
                          _ArtistStats(paintings: paintings),
                        ],
                      ),
                    ),"""

c = c.replace(old_bio, new_bio)

# Add the _ArtistStats widget before the closing of the file
# Find the _ContactCard class and add _ArtistStats before it
old_contact = """class _ContactCard extends StatelessWidget {"""

new_contact = """/// Stats row showing paintings count and total collection value for an artist.
class _ArtistStats extends StatelessWidget {
  final List paintings;

  const _ArtistStats({required this.paintings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = paintings.length;
    final totalValue = paintings.fold<double>(
      0,
      (sum, p) => sum + ((p as dynamic).price as double? ?? 0),
    );
    final currency = paintings.isNotEmpty
        ? (paintings.first as dynamic).currency as String? ?? 'USD'
        : 'USD';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.palette_outlined,
            label: 'Paintings',
            value: count.toString(),
          ),
          Container(
            width: 1,
            height: 32,
            color: scheme.onSurface.withValues(alpha: 0.15),
          ),
          _StatItem(
            icon: Icons.attach_money,
            label: 'Total value',
            value: totalValue > 0
                ? '\${totalValue.toStringAsFixed(0)} $currency'
                : '—',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: scheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {"""

c = c.replace(old_contact, new_contact)

p.write_text(c, encoding='utf-8')
print("ArtistDetail: added stats header with paintings count + total value")
