// Tests for gallery-link expiry reminders: the pure state decision
// (none / expiring / expired), the notification content, and the
// reconciliation that keeps the notification box in sync.

import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/services/gallery_link_reminder_service.dart';
import 'package:artvault/core/services/public_gallery_service.dart';
import 'package:artvault/data/repositories/notification_repository.dart';

import 'hive_test_harness.dart';

PublicGalleryStatus _status({
  bool active = true,
  String token = 'tok',
  DateTime? expiresAt,
}) =>
    PublicGalleryStatus(active: active, token: token, expiresAt: expiresAt);

void main() {
  setUpAll(initTestHive);

  group('GalleryLinkReminderService.reminderFor', () {
    final now = DateTime(2026, 8, 15, 12);

    test('no link, revoked link, or no expiry -> none', () {
      expect(
        GalleryLinkReminderService.reminderFor(null, now: now),
        GalleryLinkReminder.none,
      );
      expect(
        GalleryLinkReminderService.reminderFor(
          _status(active: false),
          now: now,
        ),
        GalleryLinkReminder.none,
      );
      expect(
        GalleryLinkReminderService.reminderFor(
          _status(expiresAt: null),
          now: now,
        ),
        GalleryLinkReminder.none,
      );
      // Empty token (link document without one) is treated as no link.
      expect(
        GalleryLinkReminderService.reminderFor(
          _status(token: ''),
          now: now,
        ),
        GalleryLinkReminder.none,
      );
    });

    test('expiry far out -> none', () {
      expect(
        GalleryLinkReminderService.reminderFor(
          _status(expiresAt: now.add(const Duration(days: 30))),
          now: now,
        ),
        GalleryLinkReminder.none,
      );
    });

    test('expiry within the warning window -> expiring (boundary)', () {
      expect(
        GalleryLinkReminderService.reminderFor(
          _status(expiresAt: now.add(const Duration(days: 3))),
          now: now,
        ),
        GalleryLinkReminder.expiring,
      );
      // Exactly the warning window still counts as expiring.
      expect(
        GalleryLinkReminderService.reminderFor(
          _status(expiresAt: now.add(const Duration(days: 7))),
          now: now,
        ),
        GalleryLinkReminder.expiring,
      );
    });

    test('expiry in the past or exactly now -> expired', () {
      expect(
        GalleryLinkReminderService.reminderFor(
          _status(expiresAt: now.subtract(const Duration(days: 1))),
          now: now,
        ),
        GalleryLinkReminder.expired,
      );
      // Expiry at this instant: the rules already deny the read.
      expect(
        GalleryLinkReminderService.reminderFor(
          _status(expiresAt: now),
          now: now,
        ),
        GalleryLinkReminder.expired,
      );
    });
  });

  group('GalleryLinkReminderService.notificationFor', () {
    final now = DateTime(2026, 8, 15, 12);

    test('expired notification has stable id, title and the expiry date', () {
      final n = GalleryLinkReminderService.notificationFor(
        'u1',
        GalleryLinkReminder.expired,
        DateTime(2026, 8, 10),
        now: now,
      );
      expect(n.id, 'gallery-link-expired-u1');
      expect(n.title, 'Gallery link expired');
      expect(n.type, 'gallery');
      expect(n.body, contains('Aug 10, 2026'));
      expect(n.body, contains('Manage gallery link'));
    });

    test('expiring notification names the remaining time', () {
      final n = GalleryLinkReminderService.notificationFor(
        'u1',
        GalleryLinkReminder.expiring,
        now.add(const Duration(days: 3)),
        now: now,
      );
      expect(n.id, 'gallery-link-expiring-u1');
      expect(n.title, 'Gallery link expiring soon');
      expect(n.body, contains('3 days'));
    });
  });

  group('GalleryLinkReminderService.check reconciliation', () {
    final now = DateTime(2026, 8, 15, 12);

    tearDown(() => NotificationRepository.instance.clearAll());

    test('adds an expiring notification once and not repeatedly', () async {
      Future<PublicGalleryStatus> loader() async => _status(
            expiresAt: now.add(const Duration(days: 2)),
          );

      await GalleryLinkReminderService.instance.check('u1', statusLoader: loader);
      await GalleryLinkReminderService.instance.check('u1', statusLoader: loader);

      final all = NotificationRepository.instance.all();
      expect(all.where((n) => n.id == 'gallery-link-expiring-u1').length, 1);
    });

    test('downgrades expiring to expired once the date passes', () async {
      await GalleryLinkReminderService.instance.check(
        'u1',
        statusLoader: () async => _status(
          expiresAt: now.add(const Duration(days: 2)),
        ),
      );
      expect(
        NotificationRepository.instance.all().map((n) => n.id),
        contains('gallery-link-expiring-u1'),
      );

      await GalleryLinkReminderService.instance.check(
        'u1',
        statusLoader: () async => _status(expiresAt: now.subtract(const Duration(days: 1))),
      );

      final ids = NotificationRepository.instance.all().map((n) => n.id).toSet();
      expect(ids, contains('gallery-link-expired-u1'));
      expect(ids, isNot(contains('gallery-link-expiring-u1')));
    });

    test('clears reminders when the link is revoked or re-published fresh', () async {
      await GalleryLinkReminderService.instance.check(
        'u1',
        statusLoader: () async => _status(expiresAt: now.add(const Duration(days: 1))),
      );
      expect(NotificationRepository.instance.all(), isNotEmpty);

      // Revoked link -> reminder goes away.
      await GalleryLinkReminderService.instance.check(
        'u1',
        statusLoader: () async => _status(active: false),
      );
      expect(NotificationRepository.instance.all(), isEmpty);

      // Fresh link with no expiry -> reminder stays away.
      await GalleryLinkReminderService.instance.check(
        'u1',
        statusLoader: () async => _status(expiresAt: null),
      );
      expect(NotificationRepository.instance.all(), isEmpty);
    });

    test('reminders are per-owner and never leak across users', () async {
      await GalleryLinkReminderService.instance.check(
        'alice',
        statusLoader: () async => _status(expiresAt: now.add(const Duration(days: 1))),
      );
      await GalleryLinkReminderService.instance.check(
        'bob',
        statusLoader: () async => _status(active: false),
      );

      final ids = NotificationRepository.instance.all().map((n) => n.id).toSet();
      expect(ids, contains('gallery-link-expiring-alice'));
      expect(ids, isNot(contains('gallery-link-expiring-bob')));
    });
  });
}
