import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/data/models/artist.dart';
import 'package:artvault/data/models/condition_report.dart';

void main() {
  group('Artist', () {
    final base = Artist(
      id: 'a1',
      name: 'Claude Monet',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );

    test('toJson/fromJson round-trips all fields', () {
      final artist = Artist(
        id: 'a2',
        name: 'Georgia O\'Keeffe',
        photoPath: '/photos/geo.jpg',
        photoUrl: 'https://cdn.example/geo.jpg',
        biography: 'American modernist.',
        nationality: 'US',
        phone: '+1 555 0100',
        email: 'geo@example.com',
        website: 'https://example.com',
        instagram: '@georgia',
        facebook: 'georgia.fb',
        awards: const ['National Medal'],
        exhibitions: const ['Whitney 2025'],
        isDeleted: false,
        needsSync: false,
        synced: true,
        ownerUid: 'u1',
        createdAt: DateTime(2025, 6, 1, 10, 30),
        updatedAt: DateTime(2025, 6, 2, 12, 45),
      );
      final decoded = Artist.fromJson(artist.toJson());
      expect(decoded.id, 'a2');
      expect(decoded.name, 'Georgia O\'Keeffe');
      expect(decoded.photoPath, '/photos/geo.jpg');
      expect(decoded.photoUrl, 'https://cdn.example/geo.jpg');
      expect(decoded.biography, 'American modernist.');
      expect(decoded.nationality, 'US');
      expect(decoded.phone, '+1 555 0100');
      expect(decoded.email, 'geo@example.com');
      expect(decoded.website, 'https://example.com');
      expect(decoded.instagram, '@georgia');
      expect(decoded.facebook, 'georgia.fb');
      expect(decoded.awards, ['National Medal']);
      expect(decoded.exhibitions, ['Whitney 2025']);
      expect(decoded.isDeleted, false);
      expect(decoded.needsSync, false);
      expect(decoded.synced, true);
      expect(decoded.ownerUid, 'u1');
      expect(decoded.createdAt, DateTime(2025, 6, 1, 10, 30));
      expect(decoded.updatedAt, DateTime(2025, 6, 2, 12, 45));
    });

    test('fromJson fills defaults for missing keys', () {
      final decoded = Artist.fromJson({'id': 'x'});
      expect(decoded.name, 'Unknown');
      expect(decoded.photoPath, '');
      expect(decoded.awards, isEmpty);
      expect(decoded.exhibitions, isEmpty);
      expect(decoded.isDeleted, false);
      expect(decoded.needsSync, true);
      expect(decoded.synced, false);
      expect(decoded.ownerUid, '');
    });

    test('fromJson coerces award lists to strings and tolerates bad dates', () {
      final decoded = Artist.fromJson({
        'id': 'y',
        'awards': ['Prize', 42],
        'createdAt': 'not-a-date',
      });
      expect(decoded.awards, ['Prize']);
    });

    test('copyWith updates only given fields and refreshes updatedAt', () {
      final before = base.updatedAt;
      final copy = base.copyWith(name: 'Renoir', synced: true);
      expect(copy.id, 'a1');
      expect(copy.name, 'Renoir');
      expect(copy.synced, true);
      expect(copy.needsSync, true);
      expect(copy.createdAt, DateTime(2026, 1, 1));
      expect(copy.updatedAt.isAfter(before), isTrue);
      final noop = base.copyWith();
      expect(noop.name, 'Claude Monet');
    });
  });

  group('AppUser', () {
    final base = AppUser(
      uid: 'u9',
      email: 'curator@example.com',
      displayName: 'Casey',
      createdAt: DateTime(2026, 2, 1),
      lastLogin: DateTime(2026, 3, 1),
    );

    test('role and plan enums expose labels and permissions', () {
      expect(AppRole.admin.label, 'Admin');
      expect(AppRole.curator.label, 'Curator');
      expect(AppRole.viewer.label, 'Viewer');
      expect(AppRole.admin.wire, 'admin');
      expect(AppRoleX.fromWire('curator'), AppRole.curator);
      expect(AppRoleX.fromWire('nonsense'), AppRole.viewer);
      expect(AppRoleX.fromWire(null), AppRole.viewer);
      expect(AppRole.admin.canEdit, isTrue);
      expect(AppRole.curator.canEdit, isTrue);
      expect(AppRole.viewer.canEdit, isFalse);
      expect(AppRole.admin.canManageUsers, isTrue);
      expect(AppRole.curator.canManageUsers, isFalse);
      expect(AppRole.admin.canManageBackups, isTrue);
      expect(AppRole.viewer.canManageBackups, isFalse);
      expect(AppRole.admin.canSeeAnalytics, isTrue);
      expect(AppRole.curator.canSeeAnalytics, isTrue);
      expect(AppRole.viewer.canSeeAnalytics, isFalse);
      expect(AppRole.admin.description, contains('Full access'));
      expect(AppRole.viewer.description, contains('Read-only'));
    });

    test('plan enums expose labels and pro checks', () {
      expect(AppPlan.free.label, 'Free');
      expect(AppPlan.pro.label, 'Pro');
      expect(AppPlan.free.isPro, isFalse);
      expect(AppPlan.pro.isPro, isTrue);
      expect(AppPlanX.fromWire('pro'), AppPlan.pro);
      expect(AppPlanX.fromWire('bogus'), AppPlan.free);
      expect(AppPlanX.fromWire(null), AppPlan.free);
      expect(AppPlan.free.wire, 'free');
    });

    test('maskedEmail masks the local part and keeps the domain', () {
      expect(AppUser.maskedEmail('karen@gmail.com'), 'k***@gmail.com');
      expect(AppUser.maskedEmail('ab@example.com'), 'a***@example.com');
      expect(AppUser.maskedEmail('x@y.io'), 'x***@y.io');
      expect(AppUser.maskedEmail('ab'), 'ab'); // too short to mask
      expect(AppUser.maskedEmail('no-at-sign'), 'n***');
      expect(AppUser.maskedEmail(''), '');
    });

    test('toJson keeps the real email; toFirestoreJson masks it', () {
      final user = base;
      expect(user.toJson()['email'], 'curator@example.com');
      expect(user.toFirestoreJson()['email'], 'c***@example.com');
      expect(user.toFirestoreJson()['uid'], 'u9');
      expect(user.toJson()['role'], 'viewer');
      expect(user.toJson()['plan'], 'free');
    });

    test('toJson/fromJson round-trips roles, plans and timestamps', () {
      final pro = AppUser(
        uid: 'u1',
        email: 'a@b.co',
        displayName: 'Admin A',
        role: AppRole.admin,
        plan: AppPlan.pro,
        createdAt: DateTime(2025, 12, 31, 23, 59),
        lastLogin: DateTime(2026, 1, 15, 8, 0),
      );
      final decoded = AppUser.fromJson(pro.toJson());
      expect(decoded.role, AppRole.admin);
      expect(decoded.plan, AppPlan.pro);
      expect(decoded.createdAt, DateTime(2025, 12, 31, 23, 59));
      expect(decoded.lastLogin, DateTime(2026, 1, 15, 8, 0));
      expect(decoded.displayName, 'Admin A');
    });

    test('fromJson tolerates missing keys and placeholder is Guest', () {
      final decoded = AppUser.fromJson({'uid': 'only'});
      expect(decoded.uid, 'only');
      expect(decoded.email, '');
      expect(decoded.displayName, 'ArtVault User');
      expect(decoded.role, AppRole.viewer);
      expect(decoded.plan, AppPlan.free);
      final p = AppUser.placeholder();
      expect(p.displayName, 'Guest');
      expect(p.uid, '');
    });

    test('copyWith replaces only the given fields', () {
      final c = base.copyWith(displayName: 'Cassidy', role: AppRole.curator);
      expect(c.displayName, 'Cassidy');
      expect(c.role, AppRole.curator);
      expect(c.email, 'curator@example.com');
      expect(c.createdAt, base.createdAt);
      expect(c.lastLogin, base.lastLogin);
    });
  });

  group('ConditionReport', () {
    test('levels are the five standard ratings', () {
      expect(ConditionReport.levels, [
        'Excellent',
        'Good',
        'Fair',
        'Poor',
        'Damaged',
      ]);
    });

    test('toJson/fromJson round-trips', () {
      final r = ConditionReport(
        id: 'c1',
        paintingId: 'p1',
        condition: 'Excellent',
        notes: 'Craquelure in upper right.',
        photoPath: '/p.jpg',
        photoUrl: 'https://cdn/p.jpg',
        inspectedAt: DateTime(2026, 4, 1, 9),
        createdAt: DateTime(2026, 4, 2),
        ownerUid: 'u1',
        isDeleted: true,
        needsSync: false,
        synced: true,
      );
      final decoded = ConditionReport.fromJson(r.toJson());
      expect(decoded.id, 'c1');
      expect(decoded.paintingId, 'p1');
      expect(decoded.condition, 'Excellent');
      expect(decoded.notes, 'Craquelure in upper right.');
      expect(decoded.photoPath, '/p.jpg');
      expect(decoded.photoUrl, 'https://cdn/p.jpg');
      expect(decoded.inspectedAt, DateTime(2026, 4, 1, 9));
      expect(decoded.createdAt, DateTime(2026, 4, 2));
      expect(decoded.ownerUid, 'u1');
      expect(decoded.isDeleted, isTrue);
      expect(decoded.needsSync, isFalse);
      expect(decoded.synced, isTrue);
    });

    test('fromJson fills defaults; copyWith touches only given fields', () {
      final decoded = ConditionReport.fromJson({'id': 'd1'});
      expect(decoded.paintingId, '');
      expect(decoded.condition, 'Good');
      expect(decoded.notes, '');
      expect(decoded.isDeleted, isFalse);
      expect(decoded.needsSync, isTrue);
      expect(decoded.synced, isFalse);
      final copied = decoded.copyWith(
        condition: 'Fair',
        notes: 'x',
        synced: true,
      );
      expect(copied.id, 'd1');
      expect(copied.condition, 'Fair');
      expect(copied.notes, 'x');
      expect(copied.synced, isTrue);
      expect(copied.createdAt, decoded.createdAt);
      expect(copied.photoUrl, '');
    });
  });
}
