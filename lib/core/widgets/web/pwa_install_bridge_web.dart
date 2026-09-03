import 'dart:async';

import 'dart:js_interop';

import 'pwa_install_bridge_stub.dart';

/// Web implementation backed by the browser's native install flow.
///
/// Listens for Chromium's non-standard `beforeinstallprompt` event and holds
/// the deferred event so [promptInstall] can open the browser's own install
/// dialog. On browsers that never fire the event (Safari, Firefox, …) the
/// streams simply stay silent and no banner is shown.
PwaInstallPlatform createPwaInstallPlatform() => _WebInstallPlatform();

extension type _Window._(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _BeforeInstallPromptEvent._(JSObject _) implements JSObject {
  /// Opens the native install dialog. Must be called synchronously from a
  /// user gesture.
  external JSPromise<_InstallPromptResult?> prompt();

  /// Resolves once the user answers the native install dialog.
  external JSPromise<_InstallPromptResult?> get userChoice;
}

extension type _InstallPromptResult._(JSObject _) implements JSObject {
  /// `'accepted'` when the user installs the app, `'dismissed'` otherwise.
  external JSString get outcome;
}

class _WebInstallPlatform implements PwaInstallPlatform {
  _WebInstallPlatform() {
    _window.addEventListener('beforeinstallprompt', _onBeforeInstall.toJS);
    _window.addEventListener('appinstalled', _onAppInstalled.toJS);
  }

  /// `globalThis` is the `Window` in browsers, which is where install
  /// events are dispatched.
  static final _Window _window = _Window._(globalContext);

  final StreamController<void> _installable = StreamController<void>.broadcast(
    sync: true,
  );
  final StreamController<void> _installed = StreamController<void>.broadcast(
    sync: true,
  );
  final StreamController<String> _installOutcome =
      StreamController<String>.broadcast(sync: true);

  /// The deferred event from `beforeinstallprompt`; `null` once used.
  JSObject? _deferredEvent;

  @override
  Stream<void> get onInstallable => _installable.stream;

  @override
  Stream<void> get onInstalled => _installed.stream;

  @override
  Stream<String> get onInstallOutcome => _installOutcome.stream;

  void _onBeforeInstall(JSObject event) {
    _deferredEvent = event;
    _installable.add(null);
  }

  void _onAppInstalled(JSObject event) {
    _deferredEvent = null;
    _installed.add(null);
  }

  @override
  void promptInstall() {
    final event = _deferredEvent;
    if (event == null) return;
    // The deferred event can only be used once — Chrome will fire a fresh
    // `beforeinstallprompt` when the install criteria are met again.
    _deferredEvent = null;
    try {
      final prompt = _BeforeInstallPromptEvent._(event);
      // `prompt()` must be called synchronously within the user gesture;
      // `userChoice` resolves afterwards with the user's answer.
      prompt.prompt();
      unawaited(_watchOutcome(prompt));
    } catch (_) {
      // Some browsers throw when prompt() is called outside a user gesture
      // or after the event has expired — nothing to show then.
    }
  }

  Future<void> _watchOutcome(_BeforeInstallPromptEvent prompt) async {
    try {
      final result = await prompt.userChoice.toDart;
      final outcome = result?.outcome.toDart;
      if (outcome != null) _installOutcome.add(outcome);
    } catch (_) {
      // Browsers that resolve the promise unusually (or throw) simply
      // produce no outcome event — nothing to report then.
    }
  }
}
