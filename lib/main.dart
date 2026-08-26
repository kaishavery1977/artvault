import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/adaptive_layout.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/ambient_background.dart';
import 'core/widgets/resume_intro_observer.dart';
import 'core/providers/providers.dart';
import 'core/router/app_router.dart';
import 'core/services/device_resolution_service.dart';
import 'core/services/file_storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/orientation_service.dart';
import 'core/services/sync_service.dart';
import 'data/local/local_database.dart';
import 'data/remote/cloud_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Offline-first boot: local storage + services first, Firebase best-effort.
  try {
    await LocalDatabase.instance.init();
    await FileStorageService.instance.init();
  } catch (e) {
    debugPrint('ArtVault boot (local): $e');
  }

  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('ArtVault boot (notifications): $e');
  }

  final cloudReady = await CloudBackend.instance.initialize();
  debugPrint(
    cloudReady ? 'ArtVault: Firebase connected' : 'ArtVault: running offline',
  );

  // Start the sync retry service (persists in Hive, retries with backoff).
  SyncService.instance.start();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );    // Pre-detect resolution from the first view (available before runApp).
  // This captures install-time resolution; subsequent launches refresh it.
  final firstView = WidgetsBinding.instance.platformDispatcher.views.first;
  final mq = MediaQueryData.fromView(firstView);
  await DeviceResolutionService.instance.detect(mq);

  // Lock orientation based on device type: phones get portrait-only,
  // tablets/foldables get both orientations.
  await OrientationService.instance.applyForDevice();

  runApp(
    ProviderScope(
      overrides: [cloudReadyProvider.overrideWith((ref) => cloudReady)],
      child: const ArtVaultApp(),
    ),
  );
}

class ArtVaultApp extends ConsumerWidget {
  const ArtVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // Paint the ambient gradient behind every route so translucent
      // surfaces (GlassCard, nav bar, dialogs) read as glass, and watch the
      // app lifecycle so returning from the background replays the splash
      // intro instead of just cold starts.
      builder: (context, child) {
        // Detect/resync resolution on every build (handles rotation,
        // fold/unfold, display setting changes). The service persists it
        // to Hive so the value survives process restarts.
        //
        // Use sizeOf + paddingOf instead of MediaQuery.of to avoid
        // subscribing to ALL media query changes (keyboard, text scale,
        // etc.) — only size and padding affect the layout.
        final size = MediaQuery.sizeOf(context);
        final padding = MediaQuery.paddingOf(context);
        DeviceResolutionService.instance.detect(
          MediaQueryData(size: size, padding: padding),
        );
        // Re-apply orientation policy on device changes (e.g. fold/unfold
        // on a foldable might switch from phone to tablet mode).
        OrientationService.instance.applyForDevice();
        final profile = DeviceResolutionService.instance.current!;
        return AdaptiveLayout(
          profile: profile,
          child: AppResumeIntroObserver(
            child: AmbientBackground(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
      locale: locale == 'en' ? null : Locale(locale),
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
        Locale('fr'),
        Locale('es'),
        Locale('it'),
        Locale('pt'),
        Locale('ar'),
        Locale('zh'),
        Locale('ja'),
      ],
      // Wire the real localization delegates so MaterialLocalizations is
      // always available (AppBar, NavigationBar, tooltips, …). Without these,
      // any non-English locale resolves to no MaterialLocalizations at all
      // and those widgets crash with "No MaterialLocalizations found".
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
