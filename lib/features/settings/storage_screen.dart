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
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$done — failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cloudReady = ref.watch(cloudReadyProvider);
    final canBackup = ref.watch(authProvider).canManageBackups;
    final usage = ref.watch(storageUsageProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Storage & data')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_outlined, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Cloud sync',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatusRow(
                  context,
                  'Firebase',
                  cloudReady ? 'Connected' : 'Offline mode',
                  cloudReady ? AppColors.success : AppColors.warning,
                ),
                if (!cloudReady)
                  Text(
                    'Connect Firebase (flutterfire configure) to enable cloud backup and sync.',
                    style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (canBackup) ...[
            GlassCard(
              padding: AppSpacing.cardPadding,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.save_alt, color: scheme.primary),
                    title: const Text('Back up now'),
                    subtitle: const Text('Local file + cloud (if connected)'),
                    trailing: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right, size: 20),
                    onTap: _busy
                        ? null
                        : () => _run(BackupService.instance.runBackup, 'Backup completed'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.cloud_upload_outlined, color: scheme.primary),
                    title: const Text('Export local backup'),
                    subtitle: const Text('A single .json bundle of your whole vault'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _busy
                        ? null
                        : () => _run(() async {
                              final file = await BackupService.instance.exportLocalBackup();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Saved to ${file.path}')),
                                );
                              }
                            }, 'Backup exported'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          GlassCard(
            padding: AppSpacing.cardPadding,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore),
              title: const Text('Restore from local backup'),
              subtitle: const Text('Replace current data with a backup file'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _busy ? null : _restore,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Storage', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: AppSpacing.md),
                _UsageRow(label: 'Paintings & thumbnails', value: usage?.images ?? 0),
                _UsageRow(label: 'Documents', value: usage?.documents ?? 0),
                _UsageRow(label: 'Backups & exports', value: usage?.exports ?? 0),
                const Divider(height: 16),
                _UsageRow(
                  label: 'Total on device',
                  value: usage?.total ?? 0,
                  bold: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'ArtVault stores everything on-device first. Nothing leaves '
                  'your device until you enable cloud sync.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final backups = _availableBackups();
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
                    DateFormat('MMM d, y • HH:mm').format(
                      DateTime.fromMillisecondsSinceEpoch(
                        file.lastModifiedSync().millisecondsSinceEpoch,
                      ),
                    ),
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
          content: const Text('This replaces your current local vault with the backup file.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
            const SnackBar(content: Text('Vault restored')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static List<File> _availableBackups() {
    final dir = FileStorageService.instance.exportsDir;
    if (!dir.existsSync()) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.take(10).toList();
  }
}

class _StatusRow extends StatelessWidget {
  final BuildContext context;
  final String label;
  final String value;
  final Color color;

  const _StatusRow(this.context, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;

  const _UsageRow({required this.label, required this.value, this.bold = false});

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
              color: bold ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
