import 'package:flutter/foundation.dart';
import 'secret_config.dart';

/// Supabase project configuration — anon key is public but we still prefer
/// --dart-define in release (no hardcoded fallback) to avoid shipping dev keys.
class SupabaseConfig {
  SupabaseConfig._();

  static String get url => SecretConfig.supabaseUrl.isNotEmpty
      ? SecretConfig.supabaseUrl
      : (kReleaseMode ? '' : 'https://mtwinlbgvuxezadbsrrl.supabase.co');

  static String get anonKey => SecretConfig.supabaseAnonKey.isNotEmpty
      ? SecretConfig.supabaseAnonKey
      : (kReleaseMode
            ? ''
            : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im10d2lubGJndnV4ZXphZGJzcnJsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2Mzg1NTcsImV4cCI6MjEwMzIxNDU1N30.11natp24PGajh04G4fIa9aQ8uYpgnBsbFnE-21iFCVs');

  /// Storage bucket names
  static const String bucketProfile = 'av-profile';
  static const String bucketPaintings = 'av-paintings';
  static const String bucketDocuments = 'av-documents';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
