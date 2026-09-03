/// Form validators shared across the app.
abstract final class Validators {
  /// RFC 5321 overall mailbox limit.
  static const int maxEmailLength = 254;

  /// Hard cap so oversized payloads never reach the hasher/auth backend
  /// (bcrypt/scrypt-style DoS guard — see Long Password DoS).
  static const int maxPasswordLength = 128;

  /// Linear-time pattern (single character classes, no nested quantifiers),
  /// so it is not ReDoS-prone; combined with [maxEmailLength] the worst case
  /// is bounded.
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (v.length > maxEmailLength) {
      return 'Email must be at most $maxEmailLength characters';
    }
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (v.length > maxPasswordLength) {
      return 'Password must be at most $maxPasswordLength characters';
    }
    return null;
  }

  static String? passwordConfirm(String? value, String? password) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? required(
    String? value, {
    String message = 'This field is required',
  }) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    if (v.length < 2) return 'Name is too short';
    return null;
  }

  static String? positiveNumber(
    String? value, {
    String message = 'Enter a positive number',
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final n = double.tryParse(v);
    if (n == null || n < 0) return message;
    return null;
  }

  static String? url(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length < 7 || v.length > 15) return 'Enter a valid phone number';
    return null;
  }
}
