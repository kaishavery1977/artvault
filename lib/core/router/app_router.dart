import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../widgets/premium/page_transition.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/splash/app_lock_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/face_scan_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/admin_code_gate_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/gallery/search_screen.dart';
import '../../features/painting/painting_detail_screen.dart';
import '../../features/gallery/print_report_view.dart';
import '../../features/painting/painting_form_screen.dart';
import '../../features/painting/painting_lightbox_screen.dart';
import '../../features/painting/trash_screen.dart';
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
import '../../features/settings/changelog_screen.dart';
import '../../features/settings/repair_images_screen.dart';
import '../../features/qr/qr_scan_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/admin/users_screen.dart';
import '../../features/admin/backup_screen.dart';
import '../../features/admin/activity_log_screen.dart';
import '../../features/admin/users_screen_web.dart';
import '../../features/admin/activity_log_screen_web.dart';
import '../../features/admin/admin_dashboard_web.dart';
import '../../features/pro/upgrade_screen.dart';

/// Routes that require edit permission (curator/admin).
const List<String> _editRoutes = [
  '/painting/new',
  '/painting/edit',
  '/artist/new',
  '/artist/edit',
];

/// Routes that require admin. (Backups are per-user, so `/backup` stays open
/// to every signed-in account.)
const List<String> _adminRoutes = ['/users', '/activity-log'];

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Shared route transition for every pushed screen — a 3D depth push
/// effect that honors reduced motion (see [depthPage]).
Page<void> _page(BuildContext context, Widget child) =>
    depthPage(context, child);

/// Pure RBAC redirect decision — the exact guard the router applies on
/// every navigation. Extracted so tests can exercise the permission model
/// without booting the whole app: viewers must be bounced off edit routes,
/// non-admins off admin routes, and the auth/onboarding flow stays intact.
String? rbacRedirect({
  required String path,
  required bool onboarded,
  required AuthState auth,
}) {
  // Splash decides where to go.
  if (path == '/splash') return null;

  if (!onboarded) {
    // /onboarding itself must never redirect (would self-loop); the auth
    // pages stay reachable so a new user can still sign in / register.
    if (path.startsWith('/onboarding')) return null;
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
  // Admin gate is reachable only after a social sign-in; let logged-in users
  // see it without bouncing to /home, and unauthenticated users go to /login.
  if (path.startsWith('/admin-gate')) {
    return loggedIn ? null : '/login';
  }
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
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final onboarded = ref.read(onboardedProvider);
      return rbacRedirect(
        path: state.matchedLocation,
        onboarded: onboarded,
        auth: auth,
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (ctx, _) => _page(ctx, const SplashScreen()),
      ),
      GoRoute(
        path: '/lock',
        pageBuilder: (ctx, _) => _page(ctx, const AppLockScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (ctx, _) => _page(ctx, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (ctx, _) => _page(ctx, const LoginScreen()),
      ),
      GoRoute(
        path: '/face-scan',
        pageBuilder: (ctx, state) => _page(
          ctx,
          state.extra is FaceScanScreen
              ? state.extra! as FaceScanScreen
              : const FaceScanScreen(mode: FaceScanMode.verify),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (ctx, _) => _page(ctx, const RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot',
        pageBuilder: (ctx, _) => _page(ctx, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/admin-gate',
        pageBuilder: (ctx, _) => _page(ctx, const AdminCodeGateScreen()),
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
        pageBuilder: (ctx, _) => _page(ctx, const PaintingFormScreen()),
      ),
      GoRoute(
        path: '/painting/edit/:id',
        pageBuilder: (ctx, state) => _page(
          ctx,
          PaintingFormScreen(paintingId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/painting/:id',
        pageBuilder: (ctx, state) => _page(
          ctx,
          PaintingDetailScreen(paintingId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/painting/:id/print',
        pageBuilder: (ctx, state) => _page(
          ctx,
          PrintReportView(paintingId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/lightbox',
        pageBuilder: (ctx, state) {
          final args = state.extra as LightboxArgs;
          return _page(
            ctx,
            PaintingLightboxScreen(
              paintings: args.paintings,
              initialIndex: args.initialIndex,
            ),
          );
        },
      ),
      GoRoute(
        path: '/trash',
        pageBuilder: (ctx, _) => _page(ctx, const TrashScreen()),
      ),
      GoRoute(
        path: '/artist/new',
        pageBuilder: (ctx, _) => _page(ctx, const ArtistFormScreen()),
      ),
      GoRoute(
        path: '/artist/edit/:id',
        pageBuilder: (ctx, state) =>
            _page(ctx, ArtistFormScreen(artistId: state.pathParameters['id'])),
      ),
      GoRoute(
        path: '/artist/:id',
        pageBuilder: (ctx, state) => _page(
          ctx,
          ArtistDetailScreen(artistId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (ctx, _) => _page(ctx, const ReportsScreen()),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (ctx, _) => _page(ctx, const SearchScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (ctx, _) => _page(ctx, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/scan',
        pageBuilder: (ctx, _) => _page(ctx, const QrScanScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (ctx, _) => _page(ctx, const ProfileScreen()),
      ),
      GoRoute(
        path: '/security',
        pageBuilder: (ctx, _) => _page(ctx, const SecurityScreen()),
      ),
      GoRoute(
        path: '/storage',
        pageBuilder: (ctx, _) => _page(ctx, const StorageScreen()),
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (ctx, _) => _page(ctx, const AboutScreen()),
      ),
      GoRoute(
        path: '/changelog',
        pageBuilder: (ctx, _) => _page(ctx, const ChangelogScreen()),
      ),
      GoRoute(
        path: '/users',
        pageBuilder: (ctx, _) => _page(
          ctx,
          kIsWeb ? const AdminUsersScreenWeb() : const UsersScreen(),
        ),
      ),
      GoRoute(
        path: '/activity-log',
        pageBuilder: (ctx, _) => _page(
          ctx,
          kIsWeb ? const ActivityLogScreenWeb() : const ActivityLogScreen(),
        ),
      ),
      GoRoute(
        path: '/backup',
        pageBuilder: (ctx, _) => _page(ctx, const BackupScreen()),
      ),
      GoRoute(
        path: '/admin-dashboard',
        pageBuilder: (ctx, _) => _page(
          ctx,
          kIsWeb ? const AdminDashboardWeb() : const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/repair-images',
        pageBuilder: (ctx, _) => _page(ctx, const RepairImagesScreen()),
      ),
      GoRoute(
        path: '/upgrade',
        pageBuilder: (ctx, _) => _page(ctx, const UpgradeScreen()),
      ),
    ],
  );

  // Re-evaluate the redirect whenever auth/onboarding state changes.
  ref.listen(authProvider, (_, _) => router.refresh());
  ref.listen(onboardedProvider, (_, _) => router.refresh());
  return router;
});
