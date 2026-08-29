import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_user.dart';
import '../../data/models/art_document.dart';
import '../../data/models/artist.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/condition_report.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/artist_repository.dart';
import '../../data/repositories/condition_report_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/painting_repository.dart';
import '../../data/remote/cloud_backend.dart';
import 'storage_providers.dart';

// ---------------------------------------------------------------------------
// Collection data
// ---------------------------------------------------------------------------

final paintingsProvider = StreamProvider<List<Painting>>((ref) {
  return PaintingRepository.instance.watchPaintings();
});

final artistsProvider = StreamProvider<List<Artist>>((ref) {
  return ArtistRepository.instance.watchArtists();
});

final documentsProvider = StreamProvider<List<ArtDocument>>((ref) {
  return DocumentRepository.instance.watchDocuments();
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  return NotificationRepository.instance.watch();
});

/// Registered user profiles (RBAC admin view).
///
/// Streams the Firestore `users` collection when Firebase is connected;
/// falls back to the signed-in profile when offline so the admin screen
/// remains usable on a device-only vault.
final usersProvider = StreamProvider<List<AppUser>>((ref) async* {
  final cloud = CloudBackend.instance;
  if (cloud.isReady) {
    yield* cloud.watchUsers().map(
      (list) => list.map(AppUser.fromJson).toList()
        ..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        ),
    );
  } else {
    yield [AuthRepository.instance.cachedUser];
  }
});

/// One recorded role change: who changed whom, from what to what, when.
class RoleAuditEntry {
  final String uid;
  final String byUid;
  final String byEmail;
  final String oldRole;
  final String newRole;
  final DateTime at;

  const RoleAuditEntry({
    required this.uid,
    required this.byUid,
    required this.byEmail,
    required this.oldRole,
    required this.newRole,
    required this.at,
  });

  factory RoleAuditEntry.fromJson(Map<String, dynamic> json) => RoleAuditEntry(
    uid: (json['uid'] as String?) ?? '',
    byUid: (json['byUid'] as String?) ?? '',
    byEmail: (json['byEmail'] as String?) ?? '',
    oldRole: (json['oldRole'] as String?) ?? 'unknown',
    newRole: (json['newRole'] as String?) ?? 'unknown',
    at: DateTime.tryParse((json['at'] as String?) ?? '') ?? DateTime.now(),
  );
}

/// Role-change audit trail (admin only), newest first.
///
/// Streams the Firestore `role_audit` collection when connected; yields an
/// empty list offline so the Users screen stays usable.
final roleAuditProvider = StreamProvider<List<RoleAuditEntry>>((ref) async* {
  final cloud = CloudBackend.instance;
  if (!cloud.isReady) {
    yield const [];
    return;
  }
  yield* cloud
      .watchCollection('role_audit')
      .map(
        (list) =>
            list.map(RoleAuditEntry.fromJson).toList()
              ..sort((a, b) => b.at.compareTo(a.at)),
      );
});

/// A revoked account marker (`revoked/{uid}`), kept so an admin can see who
/// was blocked and restore them.
class RevokedAccount {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final DateTime revokedAt;
  final String byEmail;

  const RevokedAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.revokedAt,
    required this.byEmail,
  });

  factory RevokedAccount.fromJson(Map<String, dynamic> json) => RevokedAccount(
    uid: (json['uid'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    displayName: (json['displayName'] as String?) ?? 'Revoked user',
    role: (json['role'] as String?) ?? 'unknown',
    revokedAt:
        DateTime.tryParse((json['revokedAt'] as String?) ?? '') ??
        DateTime.now(),
    byEmail: (json['byEmail'] as String?) ?? '',
  );
}

/// Revoked accounts (admin only), newest first — drives the Restore list.
final revokedProvider = StreamProvider<List<RevokedAccount>>((ref) async* {
  final cloud = CloudBackend.instance;
  if (!cloud.isReady) {
    yield const [];
    return;
  }
  yield* cloud
      .watchCollection('revoked', pk: 'uid')
      .map(
        (list) =>
            list.map(RevokedAccount.fromJson).toList()
              ..sort((a, b) => b.revokedAt.compareTo(a.revokedAt)),
      );
});

/// Single painting looked up by id.
final paintingByIdProvider =
    Provider.autoDispose.family<Painting?, String>((ref, id) {
  final paintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
  for (final painting in paintings) {
    if (painting.id == id && !painting.isDeleted) return painting;
  }
  return PaintingRepository.instance.get(id);
});

/// Documents attached to one painting.
final documentsForPaintingProvider =
    Provider.autoDispose.family<List<ArtDocument>, String>(
  (ref, id) {
    final docs = ref.watch(documentsProvider).valueOrNull ?? const [];
    return docs.where((d) => d.paintingId == id && !d.isDeleted).toList();
  },
);

/// Condition reports for every painting.
final conditionReportsProvider = StreamProvider<List<ConditionReport>>((ref) {
  return ConditionReportRepository.instance.watchReports();
});

/// Condition reports for one painting (newest first).
final conditionReportsForPaintingProvider =
    Provider.autoDispose.family<List<ConditionReport>, String>((ref, id) {
  final reports =
      ref.watch(conditionReportsProvider).valueOrNull ?? const [];
  final list =
      reports.where((r) => r.paintingId == id && !r.isDeleted).toList()
        ..sort((a, b) => b.inspectedAt.compareTo(a.inspectedAt));
  return list;
});

/// Live computed stats for the dashboard.
class VaultStats {
  final int paintings;
  final int artists;
  final int documents;
  final double collectionValue;
  final double storageBytes;
  final int favorites;

  const VaultStats({
    required this.paintings,
    required this.artists,
    required this.documents,
    required this.collectionValue,
    required this.storageBytes,
    required this.favorites,
  });
}

/// Mirrors [CloudBackend.failedUploadStreak] into Riverpod state so the UI
/// rebuilds when the streak changes (a bare [ValueNotifier] wouldn't trigger
/// widget rebuilds on its own).
class CloudSyncHealthNotifier extends Notifier<int> {
  @override
  int build() {
    final streak = CloudBackend.instance.failedUploadStreak;
    streak.addListener(_onStreakChanged);
    ref.onDispose(() => streak.removeListener(_onStreakChanged));
    return streak.value;
  }

  void _onStreakChanged() {
    state = CloudBackend.instance.failedUploadStreak.value;
  }
}

/// Number of consecutive failed media uploads (see
/// [CloudBackend.failedUploadStreak]). The home screen shows a subtle
/// "cloud sync unavailable" hint once it passes the threshold, and a
/// successful upload clears it.
final cloudSyncHealthProvider = NotifierProvider<CloudSyncHealthNotifier, int>(
  CloudSyncHealthNotifier.new,
);

/// Whether the user dismissed the "cloud sync unavailable" hint for this
/// session. Reset when the failed-upload streak drops back to 0 (a sync
/// succeeded), so a recovered cloud brings the hint back only if failures
/// start accumulating again.
final cloudSyncHintDismissedProvider =
    StateProvider.autoDispose<bool>((ref) => false);

final vaultStatsProvider = Provider<VaultStats>((ref) {
  final paintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
  final artists = ref.watch(artistsProvider).valueOrNull ?? const [];
  final documents = ref.watch(documentsProvider).valueOrNull ?? const [];

  final active = paintings.where((p) => !p.isDeleted).toList();
  final value = active.fold<double>(0, (sum, p) => sum + (p.price ?? 0));
  return VaultStats(
    paintings: active.length,
    artists: artists.where((a) => !a.isDeleted).length,
    documents: documents.where((d) => !d.isDeleted).length,
    collectionValue: value,
    storageBytes: (ref.watch(storageUsageProvider).valueOrNull?.total ?? 0)
        .toDouble(),
    favorites: active.where((p) => p.isFavorite).length,
  );
});

/// Whether the gallery is in multi-select (batch delete) mode.
/// The shell hides its upload FAB while this is true so the two don't overlap.
final gallerySelectModeProvider = StateProvider<bool>((ref) => false);

/// Whether the app has cloud connectivity (Firebase configured).
/// Populated during startup bootstrap.
final cloudReadyProvider = StateProvider<bool>((ref) => false);
