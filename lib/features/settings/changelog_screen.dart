import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../data/local/local_database.dart';

/// In-app changelog — shows what's new on each version update.
///
/// The screen reads the current version from [AppConstants] and compares it
/// against the last-seen version stored in settings. If they differ, the
/// changelog is shown automatically on first launch after an update. The
/// user can also access it manually from Settings → About → What's New.
class ChangelogScreen extends ConsumerStatefulWidget {
  const ChangelogScreen({super.key});

  @override
  ConsumerState<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends ConsumerState<ChangelogScreen> {
  @override
  void initState() {
    super.initState();
    // Mark this version as seen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalDatabase.instance.setSetting(
        AppConstants.kLastSeenVersion,
        AppConstants.appVersion,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentVersion = AppConstants.appVersion;

    return Scaffold(
      appBar: AppBar(title: const Text('What\'s New')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          // Version badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                'v$currentVersion',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Changelog entries
          ...staggerReveal(
            _changelogEntries(currentVersion).map<Widget>((entry) => _ChangelogEntryWidget(
              version: entry.version,
              date: entry.date,
              entries: entry.entries,
            )).toList(),
            initialDelay: const Duration(milliseconds: 60),
            interval: const Duration(milliseconds: 50),
            context: context,
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  static List<_ChangelogVersion> _changelogEntries(String currentVersion) {
    return [
      _ChangelogVersion(
        version: '0.1.0',
        date: 'August 2026',
        entries: [
          _ChangelogItem(Icons.security, 'Security', 'AES-256 encryption at rest for all vault data'),
          _ChangelogItem(Icons.security, 'Security', 'PBKDF2-HMAC-SHA256 passcode hashing with brute-force throttle'),
          _ChangelogItem(Icons.face, 'Security', 'Face lock with blink-liveness detection'),
          _ChangelogItem(Icons.lock, 'Security', 'HMAC integrity check on face embeddings'),
          _ChangelogItem(Icons.shield, 'Security', 'App Check on all Storage writes'),
          _ChangelogItem(Icons.speed, 'Performance', 'Rate limiting on all payment Cloud Functions'),
          _ChangelogItem(Icons.cloud, 'Sync', 'Bulletproof cloud sync with automatic retry'),
          _ChangelogItem(Icons.cloud_upload, 'Sync', 'Auto-backup of painting images to Firebase Storage'),
          _ChangelogItem(Icons.sync, 'Sync', 'Persistent sync queue with exponential backoff'),
          _ChangelogItem(Icons.person, 'Sync', 'Profile photo upload and cross-device restore'),
          _ChangelogItem(Icons.phone_android, 'Design', 'Adaptive resolution scaling for all screen sizes'),
          _ChangelogItem(Icons.phone_android, 'Design', 'Landscape-aware layouts on tablets'),
          _ChangelogItem(Icons.palette, 'Design', 'Gold accent primary color in dark mode'),
          _ChangelogItem(Icons.font_download, 'Design', 'Bundled fonts for offline-first typography'),
          _ChangelogItem(Icons.accessibility, 'Accessibility', 'Screen reader labels on all icon buttons'),
          _ChangelogItem(Icons.animation, 'Accessibility', 'Reduced-motion support for all animations'),
          _ChangelogItem(Icons.bug_report, 'Quality', 'Centralized error logging with Crashlytics'),
          _ChangelogItem(Icons.bug_report, 'Quality', 'Widget tests for painting CRUD, passcode security, and performance'),
        ],
      ),
    ];
  }
}

class _ChangelogVersion {
  final String version;
  final String date;
  final List<_ChangelogItem> entries;

  const _ChangelogVersion({
    required this.version,
    required this.date,
    required this.entries,
  });
}

class _ChangelogItem {
  final IconData icon;
  final String category;
  final String description;

  const _ChangelogItem(this.icon, this.category, this.description);
}

class _ChangelogEntryWidget extends StatelessWidget {
  final String version;
  final String date;
  final List<_ChangelogItem> entries;

  const _ChangelogEntryWidget({
    required this.version,
    required this.date,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Group by category
    final grouped = <String, List<_ChangelogItem>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.category, () => []).add(entry);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'v$version',
                style: AppTheme.display(context, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                date,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final category in grouped.keys) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),
            for (final item in grouped[category]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, size: 16, color: scheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: scheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
