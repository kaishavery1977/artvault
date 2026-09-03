import 'dart:async';

/// Platform interface for native PWA install-prompt support.
///
/// The stub is used on non-web targets (and web targets without
/// `dart.library.js_interop`) — every member is a safe no-op.
abstract class PwaInstallPlatform {
  Stream<void> get onInstallable;
  Stream<void> get onInstalled;

  /// Emits the native prompt result — `accepted` or `dismissed` — after
  /// [promptInstall] opens the browser's install dialog.
  Stream<String> get onInstallOutcome;

  void promptInstall();
}

PwaInstallPlatform createPwaInstallPlatform() => _NoopInstallPlatform();

class _NoopInstallPlatform implements PwaInstallPlatform {
  @override
  Stream<void> get onInstallable => const Stream.empty();

  @override
  Stream<void> get onInstalled => const Stream.empty();

  @override
  Stream<String> get onInstallOutcome => const Stream.empty();

  @override
  void promptInstall() {}
}
