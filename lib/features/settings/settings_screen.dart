import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/backup_service.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../data/models/app_user.dart';
import '../../data/models/art_document.dart';
import '../../data/models/artist.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/settings_repository.dart';
import 'repair_images_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final settings = SettingsRepository.instance;
    final notificationsOn = settings.notificationsEnabled;
    final autoBackup = settings.autoBackup;
    final restore = ref.watch(restoreProgressProvider);

    // Header + each settings group cascade in one after another.
    final sections = staggerReveal(
      [
        _UserCard(user: user, role: user?.role, plan: user?.plan ?? AppPlan.free),
        const SizedBox(height: AppSpacing.md),
        _Group(
          title: 'Appearance',
          children: [
            _SettingTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark mode',
              trailing: _ThemeSelector(),
            ),
            _SettingTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: _languageName(SettingsRepository.instance.locale),
              onTap: () => _showLanguageSheet(context, ref),
            ),
          ],
        ),
        _Group(
          title: 'Preferences',
          children: [
            _SettingTile(
              icon: Icons.currency_exchange,
              title: 'Preferred currency',
              subtitle: settings.preferredCurrency,
              onTap: () => _showCurrencySheet(context, ref),
            ),
            _SettingTile(
              icon: Icons.home_outlined,
              title: 'Library location',
              subtitle: settings.libraryLocation,
              onTap: () => _editLibraryLocation(context),
            ),
          ],
        ),
        _Group(
          title: 'Notifications & backup',
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              subtitle: const Text('Uploads, backups, duplicates'),
              value: notificationsOn,
              onChanged: (v) => settings.setNotificationsEnabled(v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Auto cloud backup'),
              subtitle: const Text('Backup after each change'),
              value: autoBackup,
              onChanged: (v) => settings.setAutoBackup(v),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Back up now'),
              subtitle: const Text('Local file + cloud (if connected)'),
              trailing: const Icon(Icons.arrow_forward, size: 18),
              onTap: () async {
                final result = await BackupService.instance.runBackup();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.cloud
                            ? 'Backup completed — saved locally and to the cloud'
                            : 'Backup completed — local file only (sign in for cloud)',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        _Group(
          title: 'Security',
          children: [
            _SettingTile(
              icon: Icons.shield_outlined,
              title: 'Lock & security',
              subtitle: 'App lock, passcode, face & fingerprint',
              onTap: () => context.push('/security'),
            ),
          ],
        ),
        _Group(
          title: 'Account',
          children: [
            _SettingTile(
              icon: Icons.person_outline,
              title: 'Profile',
              onTap: () => context.push('/profile'),
            ),
            if (auth.canManageUsers)
              _SettingTile(
                icon: Icons.admin_panel_settings,
                title: 'User & role management',
                onTap: () => context.push('/users'),
              ),
            _SettingTile(
              icon: Icons.workspace_premium,
              title: 'ArtVault Pro',
              subtitle: user?.plan.isPro == true
                  ? 'Active — unlimited capacity & premium gallery features'
                  : 'Free plan — unlock unlimited capacity, analytics & watermarking',
              trailing: user?.plan.isPro == true
                  ? const _ProBadge()
                  : TagChip(label: 'Free', color: Theme.of(context).colorScheme.onSurface),
              onTap: () => context.push('/upgrade'),
            ),
            _SettingTile(
              icon: Icons.backup_outlined,
              title: 'Backup & restore',
              onTap: () => context.push('/backup'),
            ),
            _SettingTile(
              icon: Icons.cloud_download_outlined,
              title: 'Restore from cloud',
              subtitle: restore?.running == true
                  ? restore!.stage
                  : 'Re-download your whole vault from the cloud',
              trailing: restore?.running == true
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: restore?.running == true
                  ? null
                  : () => _restoreFromCloud(context, ref),
            ),
            _SettingTile(
              icon: Icons.delete_sweep_outlined,
              title: 'Storage & data',
              onTap: () => context.push('/storage'),
            ),
            _SettingTile(
              icon: Icons.healing_outlined,
              title: 'Repair images',
              subtitle: _repairSubtitle(ref),
              onTap: () => context.push('/repair-images'),
            ),
            _SettingTile(
              icon: Icons.delete_outline,
              title: 'Recently deleted',
              subtitle: _trashSubtitle(ref),
              onTap: () => context.push('/trash'),
            ),
            _SettingTile(
              icon: Icons.info_outline,
              title: 'About ArtVault',
              onTap: () => context.push('/about'),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Sign out',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text(
                      'Your vault stays on this device and in the cloud.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ],
        ),
      ],
      initialDelay: const Duration(milliseconds: 60),
      interval: const Duration(milliseconds: 60),
      context: context,
    );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg + MediaQuery.paddingOf(context).top * 0.4,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          Text('Settings', style: AppTheme.display(context, size: 28)),
          const SizedBox(height: AppSpacing.md),
          ...sections,
          Center(
            child: Text(
              'ArtVault v${AppConstants.appVersion} (${AppConstants.appBuild})',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Runs the full restore-from-cloud pipeline on demand and summarises
  /// the outcome. Live progress is already shown on this tile (and the home
  /// banner) through [restoreProgressProvider]; the snackbar confirms the
  /// result once it finishes.
  static Future<void> _restoreFromCloud(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final restored = await ref.read(authProvider.notifier).restoreFromCloud();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored > 0
              ? 'Restored $restored '
                  '${restored == 1 ? 'file' : 'files'} from the cloud'
              : 'Your vault is already up to date',
        ),
      ),
    );
  }

  static const _languages = <(String, String)>[
    ('en', 'English'),
    ('de', 'Deutsch'),
    ('fr', 'Français'),
    ('es', 'Español'),
    ('it', 'Italiano'),
    ('pt', 'Português'),
    ('ar', 'العربية'),
    ('zh', '中文'),
    ('ja', '日本語'),
  ];

  static String _trashSubtitle(WidgetRef ref) {
    final paintings =
        ref.watch(paintingsProvider).valueOrNull ?? const <Painting>[];
    final count = paintings.where((p) => p.isDeleted).length;
    return switch (count) {
      0 => 'Nothing in trash',
      1 => '1 artwork — restore or remove',
      _ => '$count artworks — restore or remove',
    };
  }

  static String _repairSubtitle(WidgetRef ref) {
    final paintings =
        ref.watch(paintingsProvider).valueOrNull ?? const <Painting>[];
    final artists =
        ref.watch(artistsProvider).valueOrNull ?? const <Artist>[];
    final docs =
        ref.watch(documentsProvider).valueOrNull ?? const <ArtDocument>[];
    final missing = paintings
            .where((p) => !p.isDeleted)
            .where(RepairImagesScreen.needsRepair)
            .length +
        artists.where(RepairImagesScreen.artistPhotoMissing).length +
        docs.where(RepairImagesScreen.documentMissing).length;
    return switch (missing) {
      0 => 'All files present',
      1 => '1 file needs restoring',
      _ => '$missing files need restoring',
    };
  }

  static String _languageName(String code) {
    for (final entry in _languages) {
      if (entry.$1 == code) return entry.$2;
    }
    return 'English';
  }

  static void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final current = SettingsRepository.instance.locale;
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final entry in _languages)
              ListTile(
                title: Text(
                  entry.$2,
                  style: TextStyle(
                    fontWeight: current == entry.$1 ? FontWeight.w700 : null,
                  ),
                ),
                subtitle: Text(entry.$1, style: const TextStyle(fontSize: 11)),
                trailing: current == entry.$1 ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, entry.$1),
              ),
          ],
        ),
      ),
    ).then((locale) {
      if (locale != null) {
        SettingsRepository.instance.setLocale(locale);
        ref.read(localeProvider.notifier).state = locale;
      }
    });
  }

  static void _showCurrencySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final currency in AppConstants.currencies)
              ListTile(
                title: Text(currency),
                trailing:
                    SettingsRepository.instance.preferredCurrency == currency
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, currency),
              ),
          ],
        ),
      ),
    ).then((currency) {
      if (currency != null) {
        SettingsRepository.instance.setPreferredCurrency(currency);
        ref.invalidate(currencyProvider);
      }
    });
  }

  static void _editLibraryLocation(BuildContext context) {
    // The dialog owns its TextEditingController in a private StatefulWidget
    // and disposes it only when the route fully unmounts (after the exit
    // transition) — disposing it here would crash the frame while the
    // dialog is still animating out, exactly like the passcode dialogs did.
    showDialog<String>(
      context: context,
      builder: (_) => const _LibraryLocationDialog(),
    ).then((value) {
      if (value != null && value.isNotEmpty) {
        SettingsRepository.instance.setLibraryLocation(value);
      }
    });
  }
}

/// Edit-the-library-location dialog. Owns its [TextEditingController] and
/// disposes it only when the route fully unmounts.
class _LibraryLocationDialog extends StatefulWidget {
  const _LibraryLocationDialog();

  @override
  State<_LibraryLocationDialog> createState() => _LibraryLocationDialogState();
}

class _LibraryLocationDialogState extends State<_LibraryLocationDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: SettingsRepository.instance.libraryLocation,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Library location'),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser? user;
  final AppRole? role;
  final AppPlan? plan;

  const _UserCard({required this.user, required this.role, this.plan});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = user?.displayName ?? 'Guest';
    final email = user?.email ?? '';
    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Row(
        children: [
          Avatar(
            name: name,
            imagePath: user?.photoPath,
            imageUrl: user?.photoUrl,
            radius: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email.isEmpty ? 'Local session' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          // Flexible so the chips can wrap onto a second line at large text
          // scales instead of overflowing the card's row.
          Flexible(
            child: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TagChip(
                  label: role?.label ?? 'Viewer',
                  color: switch (role) {
                    AppRole.admin => scheme.primary,
                    AppRole.curator => const Color(0xFFF59E0B),
                    _ => scheme.onSurface,
                  },
                ),
                if (plan?.isPro == true) const _ProBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    indent: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 12)),
      trailing:
          trailing ??
          (onTap == null ? null : const Icon(Icons.chevron_right, size: 20)),
      onTap: onTap,
    );
  }
}

/// Shimmering "Pro" badge shown in the user card and the Account group.
/// Replaces the "Free" TagChip when the plan flips, so the widget-type
/// change remounts it and replays the shimmer sweep — the upgrade becomes
/// visible everywhere the moment it happens.
class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  scheme.primary.withValues(alpha: 0.28),
                  scheme.tertiary.withValues(alpha: 0.22),
                ]
              : [
                  scheme.primary.withValues(alpha: 0.14),
                  scheme.tertiary.withValues(alpha: 0.10),
                ],
        ),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: GradientShimmerText(
        text: 'Pro',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: scheme.primary,
        ),
        colors: [scheme.primary, scheme.secondary, scheme.tertiary],
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto, size: 16),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode, size: 16),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode, size: 16),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) {
        final mode = selection.first;
        SettingsRepository.instance.setThemeMode(mode);
        ref.read(themeModeProvider.notifier).state = mode;
      },
      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }
}
