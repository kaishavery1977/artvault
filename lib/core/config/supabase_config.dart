/// Supabase project configuration.
///
/// Replace these values with your actual Supabase project credentials:
///   Dashboard → Settings → API → Project URL + anon/public key
class SupabaseConfig {
  SupabaseConfig._();

  /// Your Supabase project URL (e.g. "https://xyzproject.supabase.co")
  static const String url = 'https://mtwinlbgvuxezadbsrrl.supabase.co';

  /// Your Supabase anon/public key (safe to ship in the app binary)
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im10d2lubGJndnV4ZXphZGJzcnJsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2Mzg1NTcsImV4cCI6MjEwMzIxNDU1N30.11natp24PGajh04G4fIa9aQ8uYpgnBsbFnE-21iFCVs';

  /// Storage bucket names
  static const String bucketProfile = 'av-profile';
  static const String bucketPaintings = 'av-paintings';
  static const String bucketDocuments = 'av-documents';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
