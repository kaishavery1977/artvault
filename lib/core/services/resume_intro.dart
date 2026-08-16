import 'dart:core';

/// Coordinates the "return to the app" intro replay.
///
/// [AppResumeIntroObserver] stashes the location the user was on before it
/// routes to the splash; the splash consumes it on hand-off so the user
/// returns to the same tab instead of always landing on Home. The stash is
/// time-boxed (30s) so an interrupted resume can never leak into a later
/// cold start, and only whitelisted locations are restorable — routes that
/// carry `state.extra` (e.g. the lightbox) are skipped and the splash falls
/// back to its default target.
class ResumeIntro {
  ResumeIntro._();

  /// Locations safe to restore after a resume replay: the five shell tabs
  /// and the auth flow. Everything else (detail routes, forms, dialogs) is
  /// deliberately excluded so the hand-off never lands on a route whose
  /// arguments no longer exist.
  static const Set<String> _restorable = {
    '/home',
    '/gallery',
    '/artists',
    '/documents',
    '/settings',
    '/onboarding',
    '/login',
    '/register',
    '/forgot',
  };

  static const Duration _maxAge = Duration(seconds: 30);

  static String? _target;
  static DateTime? _at;

  /// True when the splash is being mounted for a background-resume replay
  /// (set by [prepare] and still fresh). The splash reads this once in
  /// `initState` to pick the punchy short choreography; it does not consume
  /// the stash (that's [consume]'s job, at hand-off time).
  static bool get isResumeReplay {
    final at = _at;
    final target = _target;
    if (at == null || target == null) return false;
    return DateTime.now().difference(at) <= _maxAge;
  }

  /// Stash the location to return to before replaying the intro on resume.
  static void prepare(String location) {
    _target = location;
    _at = DateTime.now();
  }

  /// Returns the stashed resume target when it's fresh and restorable,
  /// clearing the state either way (each [prepare] is consumed once).
  static String? consume() {
    final at = _at;
    final target = _target;
    _target = null;
    _at = null;
    if (at == null || target == null) return null;
    final fresh = DateTime.now().difference(at) <= _maxAge;
    return fresh && _restorable.contains(target) ? target : null;
  }
}
