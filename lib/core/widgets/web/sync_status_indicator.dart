import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../providers/data_providers.dart';

/// Real-time sync status indicator for the web header.
/// Shows connection health (online/offline/syncing) and last sync time.
class SyncStatusIndicator extends ConsumerStatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  ConsumerState<SyncStatusIndicator> createState() =>
      _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  DateTime? _lastSyncTime;
  Timer? _syncCheckTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    // Check sync status periodically
    _syncCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkSyncStatus(),
    );
    _checkSyncStatus();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _syncCheckTimer?.cancel();
    super.dispose();
  }

  void _checkSyncStatus() {
    final cloudReady = ref.read(cloudReadyProvider);
    if (cloudReady && mounted) {
      setState(() {
        _lastSyncTime = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloudReady = ref.watch(cloudReadyProvider);
    final scheme = Theme.of(context).colorScheme;

    final status = cloudReady ? _SyncStatus.online : _SyncStatus.offline;
    final color = switch (status) {
      _SyncStatus.online => const Color(0xFF22C55E),
      _SyncStatus.offline => scheme.error,
      _SyncStatus.syncing => const Color(0xFFF59E0B),
    };

    final label = switch (status) {
      _SyncStatus.online => 'Live',
      _SyncStatus.offline => 'Offline',
      _SyncStatus.syncing => 'Syncing…',
    };

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showSyncDetails(context, cloudReady),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing dot
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, _) {
                  final opacity =
                      status == _SyncStatus.online ? 0.5 + 0.5 * _pulseCtrl.value : 1.0;
                  return Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: opacity),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: opacity * 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (_lastSyncTime != null) ...[
                const SizedBox(width: 6),
                Text(
                  _formatLastSync(_lastSyncTime!),
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSyncDetails(BuildContext context, bool cloudReady) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              cloudReady ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              color: cloudReady ? const Color(0xFF22C55E) : scheme.error,
            ),
            const SizedBox(width: 10),
            const Text('Sync Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusRow(
              label: 'Connection',
              value: cloudReady ? 'Connected' : 'Disconnected',
              color: cloudReady ? const Color(0xFF22C55E) : scheme.error,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Last sync',
              value: _lastSyncTime != null
                  ? '${_formatLastSync(_lastSyncTime!)} (${_lastSyncTime!.hour}:${_lastSyncTime!.minute.toString().padLeft(2, '0')})'
                  : 'Never',
              color: scheme.onSurface,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Service',
              value: 'Firebase Firestore',
              color: scheme.onSurface,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Mode',
              value: cloudReady ? 'Real-time streaming' : 'Local only',
              color: scheme.onSurface,
            ),
            if (!cloudReady) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cloud sync is unavailable. Changes are stored locally and will sync when connection is restored.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 30) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

enum _SyncStatus { online, offline, syncing }

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
