import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/file_storage_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';

/// Admin backup & restore management.
///
/// Consolidates the vault's backup story: cloud sync status, instant backup,
/// local JSON bundle export, restore from local file or from the cloud
/// snapshot, plus recent backup history and on-disk usage.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$done — failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backUpNow() async {
    setState(() => _busy = true);
    try {
      final result = await BackupService.instance.runBackup();
      if (mounted) {
        setState(() {}); // refresh the recent-backups list
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup completed — failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreLocal() async {
    setState(() => _busy = true);
    try {
      final backups = _recentBackups();
      if (backups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No backup files found in exports')),
          );
        }
        return;
      }
      final selected = await showModalBottomSheet<File>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Choose a backup file',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              for (final file in backups)
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(p.basename(file.path)),
                  subtitle: Text(
                    DateFormat(
                      'MMM d, y • HH:mm',
                    ).format(file.lastModifiedSync()),
                  ),
                  onTap: () => Navigator.pop(context, file),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      );
      if (selected == null) return;
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore backup?'),
          content: const Text(
            'This replaces your current local vault with the backup file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await BackupService.instance.restoreLocalBackup(selected);
        ref.invalidate(paintingsProvider);
        ref.invalidate(artistsProvider);
        ref.invalidate(documentsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vault restored from backup')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreCloud() async {
    await _run(() async {
      final restored = await BackupService.instance.restoreCloudBackup();
      if (!restored) {
        throw StateError(
          'No cloud snapshot found. Enable Firebase and back up first.',
        );
      }
    }, 'Cloud backup restored');
    ref.invalidate(paintingsProvider);
    ref.invalidate(artistsProvider);
    ref.invalidate(documentsProvider);
  }

  static List<File> _recentBackups() {
    final dir = FileStorageService.instance.exportsDir;
    if (!dir.existsSync()) return const [];
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
    return files.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cloudReady = ref.watch(cloudReadyProvider);
    final usage = ref.watch(storageUsageProvider).valueOrNull;
    final backups = _recentBackups();

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SizedBox(height: AppSpacing.sm),
          ...staggerReveal([
            GlassCard(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        cloudReady
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        color: cloudReady
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        cloudReady
                            ? 'Cloud backup connected'
                            : 'Running offline',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    cloudReady
                        ? 'Snapshots are mirrored to Firestore for this account.'
                        : 'Connect Firebase (flutterfire configure) to mirror your vault to the cloud.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              padding: AppSpacing.cardPadding,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.save_alt, color: scheme.primary),
                    title: const Text('Back up now'),
                    subtitle: const Text(
                      'Local bundle + cloud snapshot (if connected)',
                    ),
                    trailing: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right, size: 20),
                    onTap: _busy ? null : _backUpNow,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.cloud_upload_outlined,
                      color: scheme.primary,
                    ),
                    title: const Text('Export local backup'),
                    subtitle: const Text(
                      'A single .json bundle of your whole vault',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _busy
                        ? null
                        : () => _run(() async {
                            final file = await BackupService.instance
                                .exportLocalBackup();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Saved to ${file.path}'),
                                ),
                              );
                            }
                          }, 'Backup exported'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restore),
                    title: const Text('Restore from local backup'),
                    subtitle: const Text(
                      'Replace current data with a backup file',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _busy ? null : _restoreLocal,
                  ),
                  if (cloudReady) ...[
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cloud_sync_outlined),
                      title: const Text('Restore from cloud'),
                      subtitle: const Text('Pull the latest cloud snapshot'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: _busy ? null : _restoreCloud,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent backups',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (backups.isEmpty)
                    Text(
                      'No backups created yet. Tap “Back up now” to create your first one.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    )
                  else
                    for (final file in backups)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(
                          Icons.description_outlined,
                          size: 20,
                        ),
                        title: Text(
                          p.basename(file.path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${Formatters.bytes(file.lengthSync())} · '
                          '${DateFormat('MMM d, y • HH:mm').format(file.lastModifiedSync())}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Storage used',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _UsageRow(
                    label: 'Images & thumbnails',
                    value: usage?.images ?? 0,
                  ),
                  _UsageRow(label: 'Documents', value: usage?.documents ?? 0),
                  _UsageRow(
                    label: 'Backups & exports',
                    value: usage?.exports ?? 0,
                  ),
                  const Divider(height: 16),
                  _UsageRow(
                    label: 'Total on device',
                    value: usage?.total ?? 0,
                    bold: true,
                  ),
                ],
              ),
            ),
          ], context: context),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;

  const _UsageRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : null,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            value > 0 ? Formatters.bytes(value) : '0 B',
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
