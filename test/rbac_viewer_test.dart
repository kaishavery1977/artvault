// RBAC read-only enforcement tests:
//  - the router's pure redirect guard bounces viewers off edit routes and
//    non-admins off admin routes, while letting admins/curators through;
//  - the home screen hides edit quick actions (Upload / Sync) for viewers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/providers/providers.dart';
import 'package:artvault/core/router/app_router.dart';
import 'package:artvault/data/models/app_user.dart';
import 'package:artvault/data/models/art_document.dart';
import 'package:artvault/data/models/artist.dart';
import 'package:artvault/data/models/painting.dart';
import 'package:artvault/features/home/home_screen.dart';
import 'package:artvault/features/settings/repair_images_screen.dart';

import 'helpers.dart';
import 'package:artvault/core/theme/adaptive_layout.dart';

AppUser _user(AppRole role, {AppPlan plan = AppPlan.free}) => AppUser(
      uid: 'u1',
      email: 'u@test.dev',
      displayName: 'Tester',
      role: role,
      plan: plan,
      createdAt: DateTime(2026),
      lastLogin: DateTime(2026),
    );

AuthState _auth(AppRole role) => AuthState(
      status: AuthStatus.authenticated,
      user: _user(role),
    );

void main() {
  setUpAll(disableRuntimeFontFetching);

  group('router RBAC redirect guard', () {
    test('viewer is bounced from edit routes and admin routes', () {
      for (final path in [
        '/painting/new',
        '/painting/edit/p1',
        '/artist/new',
        '/artist/edit/a1',
        '/users',
      ]) {
        expect(
          rbacRedirect(
            path: path,
            onboarded: true,
            auth: _auth(AppRole.viewer),
          ),
          '/home',
          reason: '$path must redirect a viewer home',
        );
      }
    });

    test('curator keeps edit routes but is bounced from admin routes', () {
      for (final path in ['/painting/new', '/painting/edit/p1', '/artist/new']) {
        expect(
          rbacRedirect(
            path: path,
            onboarded: true,
            auth: _auth(AppRole.curator),
          ),
          isNull,
          reason: '$path must stay open for a curator',
        );
      }
      expect(
        rbacRedirect(
          path: '/users',
          onboarded: true,
          auth: _auth(AppRole.curator),
        ),
        '/home',
        reason: '/users must redirect a curator home',
      );
    });

    test('admin passes both edit and admin routes', () {
      for (final path in [
        '/painting/new',
        '/painting/edit/p1',
        '/artist/new',
        '/users',
        '/home',
        '/gallery',
      ]) {
        expect(
          rbacRedirect(
            path: path,
            onboarded: true,
            auth: _auth(AppRole.admin),
          ),
          isNull,
          reason: '$path must stay open for an admin',
        );
      }
    });

    test('signed-out users are sent to login, auth pages stay open', () {
      final signedOut = const AuthState(status: AuthStatus.unauthenticated);
      expect(
        rbacRedirect(path: '/home', onboarded: true, auth: signedOut),
        '/login',
      );
      expect(
        rbacRedirect(path: '/login', onboarded: true, auth: signedOut),
        isNull,
      );
      expect(
        rbacRedirect(path: '/register', onboarded: true, auth: signedOut),
        isNull,
      );
    });

    test('not-onboarded users go to onboarding', () {
      final auth = const AuthState(status: AuthStatus.unauthenticated);
      expect(
        rbacRedirect(path: '/home', onboarded: false, auth: auth),
        '/onboarding',
      );
      expect(
        rbacRedirect(path: '/login', onboarded: false, auth: auth),
        isNull,
      );
    });

    test('/onboarding itself never self-redirects', () {
      // An authenticated user on /onboarding must pass through (null), and
      // an unauthenticated user too — otherwise onboarding would loop.
      expect(
        rbacRedirect(
          path: '/onboarding',
          onboarded: false,
          auth: _auth(AppRole.viewer),
        ),
        isNull,
        reason: 'authenticated user on /onboarding must not be redirected',
      );
      expect(
        rbacRedirect(
          path: '/onboarding',
          onboarded: false,
          auth: const AuthState(status: AuthStatus.unauthenticated),
        ),
        isNull,
        reason: 'signed-out user on /onboarding must not be redirected',
      );
    });
  });

  group('home screen hides edit actions for viewers', () {
    Future<void> pumpHome(WidgetTester tester, AppRole role) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...appOverrides(introShown: true),
            authProvider.overrideWith(
              (ref) => FakeAuthController(_auth(role)),
            ),
            paintingsProvider.overrideWith((ref) => Stream.value(const [])),
            artistsProvider.overrideWith((ref) => Stream.value(const [])),
            documentsProvider.overrideWith((ref) => Stream.value(const [])),
            notificationsProvider.overrideWith((ref) => Stream.value(const [])),
            storageUsageProvider.overrideWith(
              (ref) async =>
                  const StorageUsage(images: 0, documents: 0, exports: 0),
            ),
            deviceStorageProvider.overrideWith((ref) async => null),
            currencyProvider.overrideWith((ref) => 'USD'),
          ],
          child: AdaptiveLayout(profile: testProfile, child: const MaterialApp(home: HomeScreen())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('viewer sees no Upload or Sync quick actions',
        (tester) async {
      await pumpHome(tester, AppRole.viewer);

      // Positive presence check: the UI has actually built before we assert
      // on the absence of edit actions (a blank screen would pass trivially).
      // The shimmer greeting paints two layers, so findsWidgets is right.
      expect(find.textContaining('Hello,'), findsWidgets);
      expect(find.text('This vault is read-only for your account.'), findsOneWidget);
      // The welcome hero is shown for an empty vault; its upload button must
      // NOT be there for a read-only viewer.
      expect(find.text('Upload your first painting'), findsNothing);
      expect(find.byIcon(Icons.add_photo_alternate), findsNothing);
      expect(find.byIcon(Icons.sync), findsNothing);
    });

    testWidgets('curator sees the upload affordance', (tester) async {
      await pumpHome(tester, AppRole.curator);

      expect(find.text('Upload your first painting'), findsOneWidget);
    });
  });

  group('home screen missing-images banner', () {
    Future<void> pumpHomeWith(WidgetTester tester, Painting painting) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...appOverrides(introShown: true),
            authProvider.overrideWith(
              (ref) => FakeAuthController(_auth(AppRole.admin)),
            ),
            paintingsProvider.overrideWith(
              (ref) => Stream.value([painting]),
            ),
            artistsProvider.overrideWith((ref) => Stream.value(const [])),
            documentsProvider.overrideWith((ref) => Stream.value(const [])),
            notificationsProvider.overrideWith((ref) => Stream.value(const [])),
            storageUsageProvider.overrideWith(
              (ref) async =>
                  const StorageUsage(images: 0, documents: 0, exports: 0),
            ),
            deviceStorageProvider.overrideWith((ref) async => null),
            currencyProvider.overrideWith((ref) => 'USD'),
          ],
          child: AdaptiveLayout(profile: testProfile, child: const MaterialApp(home: HomeScreen())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Painting painting({String? coverImagePath, List<String> images = const []}) {
      final now = DateTime(2026, 1, 1, 12);
      return Painting(
        id: 'p1',
        title: 'Broken Work',
        artistId: 'a1',
        artistName: 'Artist',
        coverImagePath: coverImagePath ?? '',
        images: images,
        createdAt: now,
        updatedAt: now,
      );
    }

    testWidgets('shows the banner when an artwork is missing its image',
        (tester) async {
      await pumpHomeWith(
        tester,
        painting(
          coverImagePath: '/nonexistent/path/img.jpg',
          images: ['/nonexistent/path/img.jpg'],
        ),
      );

      expect(
        find.text('1 artwork needs its image back'),
        findsOneWidget,
      );
      expect(find.text('Tap to re-pick from your gallery'), findsOneWidget);
    });

    testWidgets('no banner when every artwork has its image', (tester) async {
      await pumpHomeWith(
        tester,
        painting(coverImagePath: '', images: const []),
      );

      expect(find.textContaining('needs its image back'), findsNothing);
    });
  });

  group('repair detection statics', () {
    test('artist photo missing when file is gone and no remote copy', () {
      final a = Artist(
        id: 'a1',
        name: 'Ravi',
        photoPath: '/nonexistent/path/photo.jpg',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(RepairImagesScreen.artistPhotoMissing(a), isTrue);
    });

    test('artist photo fine when remote URL exists or file present', () {
      final remote = Artist(
        id: 'a1',
        name: 'Ravi',
        photoPath: '/nonexistent/path/photo.jpg',
        photoUrl: 'https://example.com/photo.jpg',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(RepairImagesScreen.artistPhotoMissing(remote), isFalse);
      final empty = Artist(
        id: 'a2',
        name: 'None',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(RepairImagesScreen.artistPhotoMissing(empty), isFalse);
    });

    test('document missing when file is gone and no remote copy', () {
      final d = ArtDocument(
        id: 'd1',
        paintingId: 'p1',
        type: 'Certificate',
        name: 'cert.pdf',
        localPath: '/nonexistent/path/cert.pdf',
        createdAt: DateTime(2026),
      );
      expect(RepairImagesScreen.documentMissing(d), isTrue);
    });

    test('document fine when remote URL exists', () {
      final d = ArtDocument(
        id: 'd1',
        paintingId: 'p1',
        type: 'Certificate',
        name: 'cert.pdf',
        localPath: '/nonexistent/path/cert.pdf',
        remoteUrl: 'https://example.com/cert.pdf',
        createdAt: DateTime(2026),
      );
      expect(RepairImagesScreen.documentMissing(d), isFalse);
    });
  });
}
