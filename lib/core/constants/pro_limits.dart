/// Free-tier capacity limits enforced at the point of creation. Pro users
/// have no limits (null = unlimited).
///
/// These are the *client-side* gates (fast, offline-first UX that shows the
/// upgrade prompt right where the user hits the wall). The Firestore rules
/// carry the server-side enforcement for cloud-synced collections.
abstract final class ProLimits {
  /// Max artworks a free vault can hold.
  static const int freePaintings = 25;

  /// Max artists a free vault can hold.
  static const int freeArtists = 5;

  /// Max documents a free vault can hold.
  static const int freeDocuments = 5;

  /// Max on-disk bytes for original artwork files (compressed uploads) a
  /// free vault can store.
  static const int freeStorageBytes = 100 * 1024 * 1024; // 100 MB

  /// Max expiry window (from now) a free gallery link may be set to. Pro
  /// links can live up to a year.
  static const Duration freeMaxExpiry = Duration(days: 30);
}
