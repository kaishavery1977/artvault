import 'pwa_install_bridge_stub.dart'
    if (dart.library.js_interop) 'pwa_install_bridge_web.dart';

/// Native PWA install-prompt support (Chromium `beforeinstallprompt`).
///
/// No-ops on mobile and on browsers without install-prompt support via the
/// conditional import — the streams simply never emit there, so callers can
/// listen unconditionally.
class PwaInstallSupport {
  PwaInstallSupport._();
  static final PwaInstallSupport instance = PwaInstallSupport._();

  // Type is inferred from whichever conditional-import branch is active — the
  // stub (VM) or the real web implementation. Both expose the same API, so the
  // facade must not name the platform interface here (it only exists on the
  // stub side of the conditional import).
  final _platform = createPwaInstallPlatform();

  /// Emits each time the browser signals the app is installable.
  Stream<void> get onInstallable => _platform.onInstallable;

  /// Emits after the app has been installed (`appinstalled`).
  Stream<void> get onInstalled => _platform.onInstalled;

  /// Emits the native prompt result — `accepted` or `dismissed`.
  Stream<String> get onInstallOutcome => _platform.onInstallOutcome;

  /// Shows the browser's native install dialog using the deferred
  /// `beforeinstallprompt` event. Must be called from a user gesture.
  void promptInstall() => _platform.promptInstall();
}
