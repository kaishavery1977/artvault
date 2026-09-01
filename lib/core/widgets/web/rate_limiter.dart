import 'dart:collection';

/// Client-side rate limiter for login attempts.
/// Tracks attempts per email: max 5 per 60 seconds.
class LoginRateLimiter {
  static final LoginRateLimiter instance = LoginRateLimiter._();
  LoginRateLimiter._();

  /// email -> list of attempt timestamps
  final LinkedHashMap<String, List<DateTime>> _attempts = LinkedHashMap();

  static const int maxAttempts = 5;
  static const Duration window = Duration(seconds: 60);

  /// Returns true if the email is rate-limited (too many attempts).
  bool isLimited(String email) {
    _cleanup();
    final key = email.toLowerCase().trim();
    final attempts = _attempts[key];
    if (attempts == null || attempts.isEmpty) return false;
    return attempts.length >= maxAttempts;
  }

  /// Returns seconds remaining until the user can try again.
  /// Returns 0 if not limited.
  int secondsRemaining(String email) {
    _cleanup();
    final key = email.toLowerCase().trim();
    final attempts = _attempts[key];
    if (attempts == null || attempts.length < maxAttempts) return 0;
    final oldest = attempts.first;
    final diff = window - DateTime.now().difference(oldest);
    return diff.inSeconds.clamp(0, 60);
  }

  /// Record a login attempt for the given email.
  void recordAttempt(String email) {
    final key = email.toLowerCase().trim();
    _attempts.putIfAbsent(key, () => []).add(DateTime.now());
  }

  /// Clear attempts for an email (e.g., after successful login).
  void clear(String email) {
    _attempts.remove(email.toLowerCase().trim());
  }

  /// Remove timestamps outside the sliding window.
  void _cleanup() {
    final cutoff = DateTime.now().subtract(window);
    _attempts.removeWhere((key, attempts) {
      attempts.removeWhere((t) => t.isBefore(cutoff));
      return attempts.isEmpty;
    });
  }
}
