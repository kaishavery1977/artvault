import 'package:flutter/material.dart';
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
    // Realtime may fail with WebSocket state 3 when same uid on 2 devices.
    // Fallback to REST polling so "Could not load users" never shows.
    try {
      await for (final list in cloud.watchUsers()) {
        yield list.map(AppUser.fromJson).toList()..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
      }
    } catch (_) {
      final cached = await cloud.fetchUsers();
      yield cached.map(AppUser.fromJson).toList()..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      // Poll every 10s as fallback when realtime is down
      await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
        try {
          final polled = await cloud.fetchUsers();
          yield polled.map(AppUser.fromJson).toList()..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
        } catch (_) {}
      }
    }
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
final paintingByIdProvider = Provider.autoDispose.family<Painting?, String>((
  ref,
  id,
) {
  final paintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
  for (final painting in paintings) {
    if (painting.id == id && !painting.isDeleted) return painting;
  }
  return PaintingRepository.instance.get(id);
});

/// Documents attached to one painting.
final documentsForPaintingProvider = Provider.autoDispose
    .family<List<ArtDocument>, String>((ref, id) {
      final docs = ref.watch(documentsProvider).valueOrNull ?? const [];
      return docs.where((d) => d.paintingId == id && !d.isDeleted).toList();
    });

/// Condition reports for every painting.
final conditionReportsProvider = StreamProvider<List<ConditionReport>>((ref) {
  return ConditionReportRepository.instance.watchReports();
});

/// Condition reports for one painting (newest first).
final conditionReportsForPaintingProvider = Provider.autoDispose
    .family<List<ConditionReport>, String>((ref, id) {
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
final cloudSyncHintDismissedProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

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

/// Count of local items (paintings + artists + documents) that haven't
/// been synced to the cloud yet. The home screen and sync indicator
/// use this to show a pending count.
final pendingSyncCountProvider = Provider<int>((ref) {
  final paintings = ref.watch(paintingsProvider).valueOrNull ?? [];
  final artists = ref.watch(artistsProvider).valueOrNull ?? [];
  final documents = ref.watch(documentsProvider).valueOrNull ?? [];
  final pending =
      paintings.where((p) => p.needsSync).length +
      artists.where((a) => a.needsSync).length +
      documents.where((d) => d.needsSync).length;
  return pending;
});

/// Whether the gallery is in multi-select (batch delete) mode.
/// The shell hides its upload FAB while this is true so the two don't overlap.
final gallerySelectModeProvider = StateProvider<bool>((ref) => false);

/// Whether the app has cloud connectivity (Firebase configured).
/// Populated during startup bootstrap.
final cloudReadyProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// User activity audit log
// ---------------------------------------------------------------------------

/// Types of user activity tracked in the audit log.
enum ActivityType {
  signIn,
  signOut,
  paintingUpload,
  paintingEdit,
  paintingDelete,
  artistAdd,
  artistEdit,
  artistDelete,
  documentAdd,
  documentDelete,
  roleChanged,
  planChanged,
  profileUpdate,
  backup,
  other,
}

extension ActivityTypeX on ActivityType {
  String get label => switch (this) {
    ActivityType.signIn => 'Sign in',
    ActivityType.signOut => 'Sign out',
    ActivityType.paintingUpload => 'Painting uploaded',
    ActivityType.paintingEdit => 'Painting edited',
    ActivityType.paintingDelete => 'Painting deleted',
    ActivityType.artistAdd => 'Artist added',
    ActivityType.artistEdit => 'Artist edited',
    ActivityType.artistDelete => 'Artist deleted',
    ActivityType.documentAdd => 'Document added',
    ActivityType.documentDelete => 'Document deleted',
    ActivityType.roleChanged => 'Role changed',
    ActivityType.planChanged => 'Plan changed',
    ActivityType.profileUpdate => 'Profile updated',
    ActivityType.backup => 'Backup',
    ActivityType.other => 'Other',
  };

  IconData get icon => switch (this) {
    ActivityType.signIn => Icons.login,
    ActivityType.signOut => Icons.logout,
    ActivityType.paintingUpload => Icons.brush,
    ActivityType.paintingEdit => Icons.edit,
    ActivityType.paintingDelete => Icons.delete_outline,
    ActivityType.artistAdd => Icons.person_add,
    ActivityType.artistEdit => Icons.person_outline,
    ActivityType.artistDelete => Icons.person_remove,
    ActivityType.documentAdd => Icons.description,
    ActivityType.documentDelete => Icons.delete_sweep_outlined,
    ActivityType.roleChanged => Icons.admin_panel_settings,
    ActivityType.planChanged => Icons.workspace_premium,
    ActivityType.profileUpdate => Icons.person,
    ActivityType.backup => Icons.backup_outlined,
    ActivityType.other => Icons.info_outline,
  };

  Color get color => switch (this) {
    ActivityType.signIn => const Color(0xFF22C55E),
    ActivityType.signOut => const Color(0xFF9CA3AF),
    ActivityType.paintingUpload => const Color(0xFF3B82F6),
    ActivityType.paintingEdit => const Color(0xFFF59E0B),
    ActivityType.paintingDelete => const Color(0xFFEF4444),
    ActivityType.artistAdd => const Color(0xFF8B5CF6),
    ActivityType.artistEdit => const Color(0xFF8B5CF6),
    ActivityType.artistDelete => const Color(0xFFEF4444),
    ActivityType.documentAdd => const Color(0xFF06B6D4),
    ActivityType.documentDelete => const Color(0xFFEF4444),
    ActivityType.roleChanged => const Color(0xFFF59E0B),
    ActivityType.planChanged => const Color(0xFF22C55E),
    ActivityType.profileUpdate => const Color(0xFF6366F1),
    ActivityType.backup => const Color(0xFF14B8A6),
    ActivityType.other => const Color(0xFF9CA3AF),
  };

  static ActivityType fromString(String? value) {
    for (final t in ActivityType.values) {
      if (t.name == value) return t;
    }
    return ActivityType.other;
  }
}

/// A single activity audit entry.
class ActivityAuditEntry {
  final String uid;
  final String userEmail;
  final String userName;
  final ActivityType type;
  final String description;
  final DateTime at;
  final Map<String, dynamic>? meta;

  const ActivityAuditEntry({
    required this.uid,
    required this.userEmail,
    required this.userName,
    required this.type,
    required this.description,
    required this.at,
    this.meta,
  });

  factory ActivityAuditEntry.fromJson(Map<String, dynamic> json) {
    return ActivityAuditEntry(
      uid: (json['uid'] as String?) ?? '',
      userEmail: (json['userEmail'] as String?) ?? '',
      userName: (json['userName'] as String?) ?? '',
      type: ActivityTypeX.fromString(json['type'] as String?),
      description: (json['description'] as String?) ?? '',
      at: DateTime.tryParse((json['at'] as String?) ?? '') ?? DateTime.now(),
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'userEmail': userEmail,
    'userName': userName,
    'type': type.name,
    'description': description,
    'at': at.toIso8601String(),
    if (meta != null) 'meta': meta,
  };
}

/// Streams the `activity_audit` collection — a live feed of user actions
/// across the vault. Newest first. Falls back to empty when offline.
final activityAuditProvider = StreamProvider<List<ActivityAuditEntry>>((
  ref,
) async* {
  final cloud = CloudBackend.instance;
  if (!cloud.isReady) {
    yield const [];
    return;
  }
  yield* cloud
      .watchCollection('activity_audit')
      .map(
        (list) =>
            list.map(ActivityAuditEntry.fromJson).toList()
              ..sort((a, b) => b.at.compareTo(a.at)),
      );
});

/// Logs a user activity entry to the Firestore `activity_audit` collection.
/// Fire-and-forget: best-effort write that never throws.
Future<void> logActivity(
  ActivityType type,
  String description, {
  Map<String, dynamic>? meta,
}) async {
  final cloud = CloudBackend.instance;
  if (!cloud.isReady || cloud.currentUid.isEmpty) return;
  try {
    final me = AuthRepository.instance.cachedUser;
    await cloud.addDoc('activity_audit', {
      'uid': me.uid,
      'userEmail': me.email,
      'userName': me.displayName,
      'type': type.name,
      'description': description,
      'at': DateTime.now().toIso8601String(),
      'meta': ?meta,
    });
  } catch (_) {
    // Best-effort — audit failures must never block the action.
  }
}
