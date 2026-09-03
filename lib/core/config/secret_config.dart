/// Sensitive config via --dart-define (never hardcoded).
/// Build: flutter build apk --dart-define=SUPABASE_URL=https://xxx --dart-define=SUPABASE_ANON_KEY=eyJ...
class SecretConfig {
  SecretConfig._();
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
