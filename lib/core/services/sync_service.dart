import 'dart:async';
import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../data/local/local_database.dart';
import '../../data/remote/cloud_backend.dart';
import '../../data/repositories/painting_repository.dart';
import 'app_logger.dart';

/// Persistent sync queue with exponential backoff retry.
///
/// When a cloud operation fails, it's recorded with a timestamp and retry
/// count. On the next periodic check (or app resume), failed operations
/// are retried with increasing delays:
///
///   Attempt 1 → 5 seconds
///   Attempt 2 → 25 seconds
///   Attempt 3 → 125 seconds (~2 min)
///   Attempt 4 → 600 seconds (capped at 10 min)
///
/// The queue persists in Hive so retries survive app restarts.
class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  Timer? _periodicTimer;
  bool _syncing = false;

  static const String _boxQueue = AppConstants.boxSyncQueue;

  /// Queues an operation for retry.
  Future<void> enqueue(
    String id,
    String type, {
    Map<String, dynamic>? data,
  }) async {
    await LocalDatabase.instance.put(_boxQueue, id, {
      'id': id,
      'type': type,
      'data': data ?? {},
      'attempts': 0,
      'nextRetryAt': DateTime.now().millisecondsSinceEpoch,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    AppLogger.info('SyncService: queued $type/$id');
  }

  /// Removes a completed or abandoned operation from the queue.
  Future<void> dequeue(String id) async {
    await LocalDatabase.instance.delete(_boxQueue, id);
  }

  /// Returns all pending operations.
  List<Map<String, dynamic>> get pending => LocalDatabase.instance
      .getAll(_boxQueue)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  /// Starts the sync service: runs a periodic retry timer.
  void start() {
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _processQueue(),
    );
    Future.microtask(_processQueue);
  }

  /// Stops the sync service.
  void stop() {
    _periodicTimer?.cancel();
  }

  /// Processes the queue: retries operations whose backoff has elapsed.
  Future<void> _processQueue() async {
    if (_syncing) return;
    if (!CloudBackend.instance.isReady) return;

    _syncing = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final items = pending.where((item) {
        final nextRetry = item['nextRetryAt'] as int? ?? 0;
        return now >= nextRetry;
      }).toList();

      for (final item in items) {
        await _retryOperation(item);
      }
    } finally {
      _syncing = false;
    }
  }

  /// Retries a single operation with exponential backoff on failure.
  Future<void> _retryOperation(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    final type = item['type'] as String;
    final attempts = (item['attempts'] as int?) ?? 0;

    try {
      switch (type) {
        case 'push':
          final painting = PaintingRepository.instance.get(id);
          if (painting == null) {
            await dequeue(id);
            return;
          }
          await PaintingRepository.instance.syncNow();
        case 'delete':
          await CloudBackend.instance.remove('paintings', id);
        case 'pull':
          await PaintingRepository.instance.syncNow();
      }
      await dequeue(id);
      AppLogger.info(
        'SyncService: $type/$id succeeded (attempt ${attempts + 1})',
      );
    } catch (e) {
      final nextDelay = _backoffDelay(attempts + 1);
      AppLogger.warning(
        'SyncService: $type/$id failed (attempt ${attempts + 1}), retry in ${nextDelay.inSeconds}s',
      );
      await LocalDatabase.instance.put(_boxQueue, id, {
        ...item,
        'attempts': attempts + 1,
        'nextRetryAt':
            DateTime.now().millisecondsSinceEpoch + nextDelay.inMilliseconds,
        'lastError': e.toString(),
      });
    }
  }

  /// Exponential backoff, capped at 10 minutes.
  /// Attempt 1 → 5 s, Attempt 2 → 25 s, Attempt 3 → 125 s (~2 min),
  /// Attempt 4 → 625 s (capped to 10 min).
  Duration _backoffDelay(int attempt) {
    const base = 5; // seconds
    const maxSeconds = 600; // 10 minutes
    final delaySeconds = (base * math.pow(5, attempt - 1)).toInt().clamp(0, maxSeconds);
    return Duration(seconds: delaySeconds);
  }
}
