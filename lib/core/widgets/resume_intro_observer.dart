import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
import '../services/resume_intro.dart';

/// Replays the cinematic splash intro every time the app returns from the
/// background — not just on cold start — then hands off back to the tab the
/// user was on. Sits above the Navigator (in MaterialApp's builder) so it can
/// drive the router directly.
///
/// Deliberately ignores transient `inactive` states (notification shade,
/// permission dialogs, in-app overlays): only a real backgrounding
/// (`paused` / `hidden`) triggers the replay. Returning while the cold-start
/// splash is still playing, or while already at the lock screen, is a no-op.
class AppResumeIntroObserver extends ConsumerStatefulWidget {
  final Widget child;

  const AppResumeIntroObserver({super.key, required this.child});

  @override
  ConsumerState<AppResumeIntroObserver> createState() =>
      _AppResumeIntroObserverState();
}

class _AppResumeIntroObserverState extends ConsumerState<AppResumeIntroObserver>
    with WidgetsBindingObserver {
  /// Set when the app actually went to the background; cleared on resume.
  bool _backgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _backgrounded = true;
        break;
      case AppLifecycleState.resumed:
        if (!_backgrounded) return;
        _backgrounded = false;
        // Cold-start splash still playing, or already at the lock screen:
        // nothing to replay.
        final router = ref.read(routerProvider);
        final location = router.state.uri.toString();
        if (location == '/splash' || location == '/lock') return;
        ResumeIntro.prepare(location);
        router.go('/splash');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
