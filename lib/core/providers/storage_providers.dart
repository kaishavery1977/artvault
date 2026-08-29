import 'package:disk_space_2/disk_space_2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/file_storage_service.dart';

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

/// On-disk storage usage (bytes) broken down by category.
class StorageUsage {
  final int images;
  final int documents;
  final int exports;

  const StorageUsage({this.images = 0, this.documents = 0, this.exports = 0});

  int get total => images + documents + exports;

  /// Bytes that count against the free-tier storage cap: original artwork
  /// files plus attached documents (exports/backups are excluded).
  int get countedBytes => images + documents;
}

final storageUsageProvider =
    FutureProvider.autoDispose<StorageUsage>((ref) async {
  final breakdown = await FileStorageService.instance.storageBreakdown();
  return StorageUsage(
    images: breakdown.images,
    documents: breakdown.documents,
    exports: breakdown.exports,
  );
});

/// Phone-wide disk space in bytes (null when the platform doesn't expose it).
class DeviceStorage {
  final int freeBytes;
  final int totalBytes;

  const DeviceStorage({required this.freeBytes, required this.totalBytes});

  int get usedBytes => totalBytes - freeBytes;

  /// Fraction (0..1) of the phone's storage currently in use.
  double get usedFraction => totalBytes > 0 ? usedBytes / totalBytes : 0;
}

/// Reads the phone's total and free disk space so the UI can show how much
/// storage remains on the device, not just what the vault itself uses.
///
/// `disk_space_2` returns values in mebibytes (2^20 bytes) on Android and
/// iOS, so convert to bytes with 1024*1024 — not 1024^3.
final deviceStorageProvider =
    FutureProvider.autoDispose<DeviceStorage?>((ref) async {
  try {
    final freeMiB = await DiskSpace.getFreeDiskSpace;
    final totalMiB = await DiskSpace.getTotalDiskSpace;
    if (freeMiB == null || totalMiB == null) return null;
    const mib = 1024 * 1024;
    return DeviceStorage(
      freeBytes: (freeMiB * mib).round(),
      totalBytes: (totalMiB * mib).round(),
    );
  } catch (_) {
    return null; // graceful fallback: card shows vault-only usage as before
  }
});
