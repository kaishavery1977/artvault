import '../../data/models/app_notification.dart';
import '../../data/remote/cloud_backend.dart';
import '../../data/repositories/notification_repository.dart';
import '../utils/formatters.dart';
import 'public_gallery_service.dart';

/// Which reminder (if any) applies to a published gallery link.
enum GalleryLinkReminder { none, expiring, expired }

/// Keeps the owner's in-app notifications in sync with their published
/// gallery link: warns when the link is about to expire and reports once it
/// has. Runs best-effort at startup (after auth) and never throws — a
/// reminder hiccup must never slow the app down.
///
/// Notifications are local and keyed per owner, so re-publishing or revoking
/// the link reconciles them away (no stale "expiring" notices for a link
/// that no longer exists).
class GalleryLinkReminderService {
  GalleryLinkReminderService._();

  static final GalleryLinkReminderService instance =
      GalleryLinkReminderService._();

  /// How far in advance the owner is warned that the link is about to die.
  static const Duration warnBefore = Duration(days: 7);

  static const String _expiringIdPrefix = 'gallery-link-expiring';
  static const String _expiredIdPrefix = 'gallery-link-expired';

  static String _expiringId(String uid) => '$_expiringIdPrefix-$uid';
  static String _expiredId(String uid) => '$_expiredIdPrefix-$uid';

  /// Pure decision: which reminder the given link state warrants.
  ///
  /// A link warrants *expired* once its expiry time has passed (the storage
  /// rules stop serving it from that moment, even though the link document
  /// still reports `active`). *Expiring* covers the [warnBefore] window
  /// before that. Everything else — no link, revoked, no expiry — is none.
  static GalleryLinkReminder reminderFor(
    PublicGalleryStatus? status, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (status == null ||
        !status.active ||
        status.token.isEmpty ||
        status.expiresAt == null) {
      return GalleryLinkReminder.none;
    }
    final expiresAt = status.expiresAt!;
    if (!expiresAt.isAfter(current)) return GalleryLinkReminder.expired;
    if (expiresAt.difference(current) <= warnBefore) {
      return GalleryLinkReminder.expiring;
    }
    return GalleryLinkReminder.none;
  }

  /// Builds the notification for a given reminder (pure, so it's testable).
  static AppNotification notificationFor(
    String uid,
    GalleryLinkReminder reminder,
    DateTime? expiresAt, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    return switch (reminder) {
      GalleryLinkReminder.expired => AppNotification(
          id: _expiredId(uid),
          title: 'Gallery link expired',
          body: 'Your public gallery link expired on '
              '${Formatters.date(expiresAt)} and no longer resolves. '
              'Open any painting → More → Manage gallery link to publish '
              'a new one.',
          type: 'gallery',
          createdAt: current,
        ),
      GalleryLinkReminder.expiring => AppNotification(
          id: _expiringId(uid),
          title: 'Gallery link expiring soon',
          body: 'Your public gallery link stops working in '
              '${_friendly(expiresAt!.difference(current))}. Open any '
              'painting → More → Manage gallery link to extend it.',
          type: 'gallery',
          createdAt: current,
        ),
      GalleryLinkReminder.none => throw ArgumentError(
          'No notification exists for the none reminder.',
        ),
    };
  }

  /// Reconciles the owner's gallery-link notifications with the current
  /// link state. Best-effort and safe to fire-and-forget.
  ///
  /// [statusLoader] is injectable for tests; production callers use the
  /// default (the real link status, gated on the cloud being ready).
  Future<void> check(
    String uid, {
    Future<PublicGalleryStatus?> Function()? statusLoader,
  }) async {
    if (uid.isEmpty) return;
    if (statusLoader == null) {
      if (!CloudBackend.instance.isReady) return;
      statusLoader = () => PublicGalleryService.instance.status(uid);
    }
    try {
      final status = await statusLoader();
      final reminder = reminderFor(status);
      final repo = NotificationRepository.instance;
      final existing = repo.all().map((n) => n.id).toSet();
      final current = DateTime.now();

      if (reminder == GalleryLinkReminder.none) {
        if (existing.contains(_expiringId(uid))) {
          await repo.remove(_expiringId(uid));
        }
        if (existing.contains(_expiredId(uid))) {
          await repo.remove(_expiredId(uid));
        }
        return;
      }

      final targetId = reminder == GalleryLinkReminder.expiring
          ? _expiringId(uid)
          : _expiredId(uid);
      final staleId = reminder == GalleryLinkReminder.expiring
          ? _expiredId(uid)
          : _expiringId(uid);

      // Add only once — re-adding on every launch would re-unread it.
      if (!existing.contains(targetId)) {
        await repo.add(
          notificationFor(uid, reminder, status?.expiresAt, now: current),
        );
      }
      if (existing.contains(staleId)) {
        await repo.remove(staleId);
      }
    } catch (_) {
      // Best-effort reminder — never block startup on this.
    }
  }

  static String _friendly(Duration d) {
    if (d.inDays >= 7) {
      final weeks = d.inDays ~/ 7;
      return '$weeks week${weeks == 1 ? '' : 's'}';
    }
    if (d.inDays >= 1) return '${d.inDays} day${d.inDays == 1 ? '' : 's'}';
    if (d.inHours >= 1) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
    return '${d.inMinutes.clamp(1, 59)} minutes';
  }
}
