import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/splash/app_lock_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/face_scan_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/gallery/search_screen.dart';
import '../../features/painting/painting_detail_screen.dart';
import '../../features/painting/painting_form_screen.dart';
import '../../features/painting/painting_lightbox_screen.dart';
import '../../features/artists/artists_screen.dart';
import '../../features/artists/artist_detail_screen.dart';
import '../../features/artists/artist_form_screen.dart';
import '../../features/documents/documents_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/profile_screen.dart';
import '../../features/settings/security_screen.dart';
import '../../features/settings/storage_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/qr/qr_scan_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/admin/users_screen.dart';
import '../../features/admin/backup_screen.dart';

/// Routes that require edit permission (curator/admin).
const List<String> _editRoutes = [
  '/painting/new',
  '/painting/edit',
  '/artist/new',
  '/artist/edit',
];

/// Routes that require admin. (Backups are per-user, so `/backup` stays open
/// to every signed-in account.)
const List<String> _adminRoutes = ['/users'];

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Shared route transition — a subtle fade with a gentle upward drift that
/// makes every screen change feel cohesive and premium.
Page<void> _page(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final onboarded = ref.read(onboardedProvider);
      final path = state.matchedLocation;

      // Splash decides where to go.
      if (path == '/splash') return null;

      if (!onboarded) {
        return path.startsWith('/login') || path.startsWith('/register')
            ? null
            : '/onboarding';
      }
      if (auth.status == AuthStatus.unknown) return '/splash';

      final loggedIn = auth.status == AuthStatus.authenticated;

      // Public auth pages.
      final isAuthPage =
          path.startsWith('/login') ||
          path.startsWith('/register') ||
          path.startsWith('/forgot');
      if (!loggedIn) {
        return isAuthPage ? null : '/login';
      }
      if (isAuthPage) {
        return '/home';
      }

      // RBAC guards.
      if (_editRoutes.any(path.startsWith) && !auth.canEdit) {
        return '/home';
      }
      if (_adminRoutes.any(path.startsWith) && !auth.canManageUsers) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, _) => _page(const SplashScreen()),
      ),
      GoRoute(
        path: '/lock',
        pageBuilder: (_, _) => _page(const AppLockScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, _) => _page(const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, _) => _page(const LoginScreen()),
      ),
      GoRoute(
        path: '/face-scan',
        pageBuilder: (_, state) => _page(
          state.extra is FaceScanScreen
              ? state.extra! as FaceScanScreen
              : const FaceScanScreen(mode: FaceScanMode.verify),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, _) => _page(const RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot',
        pageBuilder: (_, _) => _page(const ForgotPasswordScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gallery',
                builder: (_, _) => const GalleryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/artists',
                builder: (_, _) => const ArtistsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/documents',
                builder: (_, _) => const DocumentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/painting/new',
        pageBuilder: (_, _) => _page(const PaintingFormScreen()),
      ),
      GoRoute(
        path: '/painting/edit/:id',
        pageBuilder: (_, state) =>
            _page(PaintingFormScreen(paintingId: state.pathParameters['id'])),
      ),
      GoRoute(
        path: '/painting/:id',
        pageBuilder: (_, state) => _page(
          PaintingDetailScreen(paintingId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/lightbox',
        pageBuilder: (_, state) {
          final args = state.extra as LightboxArgs;
          return _page(
            PaintingLightboxScreen(
              paintings: args.paintings,
              initialIndex: args.initialIndex,
            ),
          );
        },
      ),
      GoRoute(
        path: '/artist/new',
        pageBuilder: (_, _) => _page(const ArtistFormScreen()),
      ),
      GoRoute(
        path: '/artist/edit/:id',
        pageBuilder: (_, state) =>
            _page(ArtistFormScreen(artistId: state.pathParameters['id'])),
      ),
      GoRoute(
        path: '/artist/:id',
        pageBuilder: (_, state) =>
            _page(ArtistDetailScreen(artistId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (_, _) => _page(const ReportsScreen()),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, _) => _page(const SearchScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, _) => _page(const NotificationsScreen()),
      ),
      GoRoute(
        path: '/scan',
        pageBuilder: (_, _) => _page(const QrScanScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, _) => _page(const ProfileScreen()),
      ),
      GoRoute(
        path: '/security',
        pageBuilder: (_, _) => _page(const SecurityScreen()),
      ),
      GoRoute(
        path: '/storage',
        pageBuilder: (_, _) => _page(const StorageScreen()),
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (_, _) => _page(const AboutScreen()),
      ),
      GoRoute(
        path: '/users',
        pageBuilder: (_, _) => _page(const UsersScreen()),
      ),
      GoRoute(
        path: '/backup',
        pageBuilder: (_, _) => _page(const BackupScreen()),
      ),
    ],
  );

  // Re-evaluate the redirect whenever auth/onboarding state changes.
  ref.listen(authProvider, (_, _) => router.refresh());
  ref.listen(onboardedProvider, (_, _) => router.refresh());
  return router;
});
