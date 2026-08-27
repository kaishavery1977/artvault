/// Global application constants for ArtVault.
abstract final class AppConstants {
  static const String appName = 'ArtVault';
  static const String appTagline = 'Your Private Gallery';

  /// Keep in sync with `version:` and `versionCode:` in pubspec.yaml.
  static const String appVersion = '0.1.0';
  static const String appBuild = '1';

  /// Support email used for the in-app feedback entry (project-owned
  /// alias, not a personal address).
  static const String supportEmail = 'support@artvault.app';

  /// Play Store listing used by "Rate ArtVault" and the share text.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.artvault.artvault';

  // Storage keys
  static const String kOnboarded = 'onboarded';

  /// True once the user has seen the full cinematic splash intro; later
  /// launches get the shorter quick intro instead.
  static const String kSplashIntroShown = 'splash_intro_shown';
  static const String kSessionUid = 'session_uid';
  static const String kRememberMe = 'remember_me';
  static const String kThemeMode = 'theme_mode';
  static const String kLocale = 'locale';
  static const String kBiometricEnabled = 'biometric_enabled';
  static const String kFaceLockEnabled = 'face_lock_enabled';
  static const String kAppLockEnabled = 'app_lock_enabled';

  /// Secure-storage key holding the App Lock passcode hash (a salted
  /// PBKDF2-HMAC-SHA256 digest; the raw PIN is never persisted).
  static const String kPasscodeHash = 'passcode_hash';

  /// Settings keys for the passcode brute-force throttle.
  static const String kPasscodeFailures = 'passcode_failures';
  static const String kPasscodeLockedUntil = 'passcode_locked_until';

  /// Secure-storage key holding the enrolled face embedding (JSON float list)
  /// used by Face lock to match the owner instead of accepting any face.
  static const String kFaceEmbedding = 'face_embedding';

  /// Number of digits in the App Lock passcode.
  static const int kPasscodeLength = 4;

  /// Wrong passcode attempts allowed before throttling starts.
  static const int kPasscodeMaxAttempts = 5;

  /// Lockout after the first throttle threshold is crossed; each further
  /// failure doubles the wait until [kPasscodeLockoutMax].
  static const Duration kPasscodeLockoutStart = Duration(seconds: 30);
  static const Duration kPasscodeLockoutMax = Duration(minutes: 10);
  static const String kNotificationsEnabled = 'notifications_enabled';
  static const String kAutoBackup = 'auto_backup_enabled';

  /// JSON list of celebration history entries (`{id, at}`), newest first —
  /// used both for the 24h cooldown and the About-screen transparency list.
  static const String kCelebrationHistory = 'celebration_history';
  static const String kRole = 'user_role';
  static const String kCurrency = 'preferred_currency';
  static const String kLibraryLocation = 'library_location';

  /// Tracks the last app version the user saw the changelog for.
  static const String kLastSeenVersion = 'last_seen_version';

  // Storage box names
  static const String boxSettings = 'av_settings_v2';
  static const String boxPaintings = 'av_paintings';
  static const String boxArtists = 'av_artists';
  static const String boxDocuments = 'av_documents';
  static const String boxConditionReports = 'av_condition_reports';
  static const String boxNotifications = 'av_notifications';
  static const String boxSyncQueue = 'av_sync_queue';
  static const String boxProfile = 'av_profile';

  // Categories & mediums & styles vocabulary (used for filters + AI tagging)
  static const List<String> categories = [
    'Abstract',
    'Landscape',
    'Portrait',
    'Still Life',
    'Figurative',
    'Modern',
    'Contemporary',
    'Impressionist',
    'Expressionist',
    'Surreal',
    'Minimalist',
    'Religious',
    'Mythological',
    'Architecture',
    'Floral',
    'Marine',
    'Wildlife',
    'Urban',
    'Calligraphy',
    'Other',
  ];

  static const List<String> mediums = [
    'Oil on Canvas',
    'Acrylic on Canvas',
    'Watercolor',
    'Gouache',
    'Pastel',
    'Ink',
    'Charcoal',
    'Graphite',
    'Mixed Media',
    'Oil on Board',
    'Tempera',
    'Fresco',
    'Encaustic',
    'Photography',
    'Digital Art',
    'Print',
    'Sculpture',
    'Textile',
    'Other',
  ];

  static const List<String> styles = [
    'Realism',
    'Impressionism',
    'Expressionism',
    'Cubism',
    'Surrealism',
    'Abstract',
    'Minimalism',
    'Pop Art',
    'Baroque',
    'Rococo',
    'Romanticism',
    'Renaissance',
    'Modernism',
    'Contemporary',
    'Naïve',
    'Post-Impressionism',
    'Art Deco',
    'Art Nouveau',
    'Fauvism',
    'Other',
  ];

  static const List<String> documentTypes = [
    'Certificate',
    'Invoice',
    'Ownership',
    'Insurance',
    'Biography',
    'Restoration Report',
    'Appraisal',
    'Other',
  ];

  static const List<String> currencies = [
    'USD',
    'EUR',
    'GBP',
    'INR',
    'AED',
    'CAD',
    'AUD',
    'JPY',
    'CHF',
    'SGD',
  ];

  static const List<String> dimensionUnits = ['cm', 'in'];

  static const List<String> availabilityOptions = [
    'Available',
    'Sold',
    'On Loan',
    'In Storage',
    'Restoration',
    'Not For Sale',
  ];

  /// Deep-link scheme used by generated QR codes:
  /// `artvault://artwork/{id}`.
  static const String deepLinkScheme = 'artvault';

  /// Similarity threshold (0..1) above which an uploaded artwork is flagged
  /// as a likely duplicate of an existing one.
  static const double duplicateThreshold = 0.86;

  /// Max images kept per painting (performance guard).
  static const int maxImagesPerPainting = 12;

  /// Compressed upload size.
  static const int maxUploadDimension = 2400;
  static const int coverThumbDimension = 480;
}
