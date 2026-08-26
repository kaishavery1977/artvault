import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Centralized logger that routes messages based on build mode.
///
/// In **debug** mode: all messages go to `debugPrint` for logcat/console.
/// In **release** mode: errors go to Crashlytics `recordError`; info goes
/// as Crashlytics custom keys for context during crash triage.
///
/// Usage:
///   AppLogger.error('Sync failed', error: e, stack: stack);
///   AppLogger.info('Vault restored', extra: {'count': restored});
///   AppLogger.debug('Frame processed');
class AppLogger {
  AppLogger._();

  // ------------------------------------------------------------------ Info --

  /// Informational log. In release mode, sets a Crashlytics custom key so
  /// the next crash report carries this context.
  static void info(String message, {Map<String, String>? extra}) {
    if (kDebugMode) {
      debugPrint('ℹ️ ArtVault: $message');
    } else {
      // Crashlytics custom keys are sticky — they appear on every future
      // report until overwritten. Use for transient context only.
      try {
        FirebaseCrashlytics.instance.setCustomKey('last_info', message);
        if (extra != null) {
          for (final e in extra.entries) {
            FirebaseCrashlytics.instance.setCustomKey(e.key, e.value);
          }
        }
      } catch (_) {
        // Crashlytics not initialized — silent no-op.
      }
    }
  }

  // ------------------------------------------------------------------ Debug --

  /// Debug-only log. Stripped from release builds by tree-shaking when
  /// `kDebugMode` is false (the call is still made, but the string is
  /// short-circuited before any real work).
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 ArtVault: $message');
    }
  }

  // ------------------------------------------------------------------ Error --

  /// Errors and exceptions. In release mode, recorded to Crashlytics with
  /// full stack trace and optional `reason` string for crash triage.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
  }) {
    if (kDebugMode) {
      debugPrint('❌ ArtVault: $message${error != null ? ' ($error)' : ''}');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString().split('\n').take(5).join('\n'));
      }
    } else {
      try {
        final exception = error ?? message;
        final trace = stackTrace ?? StackTrace.current;
        FirebaseCrashlytics.instance.recordError(
          exception,
          trace,
          reason: reason ?? message,
          fatal: fatal,
        );
        // Also set as custom key so non-fatal errors show in the dashboard.
        FirebaseCrashlytics.instance.setCustomKey('last_error', message);
      } catch (_) {
        // Crashlytics not available — fall back to debugPrint in release.
        debugPrint('❌ ArtVault: $message');
      }
    }
  }

  // ------------------------------------------------------------- Warning --

  /// Warnings. In release mode, recorded as non-fatal to Crashlytics.
  static void warning(String message, {Object? error}) {
    if (kDebugMode) {
      debugPrint('⚠️ ArtVault: $message');
    } else {
      try {
        FirebaseCrashlytics.instance.setCustomKey('last_warning', message);
        if (error != null) {
          FirebaseCrashlytics.instance.recordError(
            error,
            StackTrace.current,
            reason: message,
          );
        }
      } catch (_) {}
    }
  }
}
