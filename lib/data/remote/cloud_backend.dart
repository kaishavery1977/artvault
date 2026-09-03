// ignore_for_file: deprecated_member_use
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart'
    show ValueNotifier, debugPrint, kDebugMode, kIsWeb;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../core/config/supabase_config.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/google_drive_service.dart';
import '../../firebase_options.dart';

/// Centralised gateway to Firebase (auth, analytics, crashlytics) and
/// Supabase (database, storage).
///
/// The whole app degrades gracefully: if either service isn't configured,
/// every call here is a safe no-op and the app keeps working fully offline
/// (offline-first architecture).
class CloudBackend {
  CloudBackend._();

  static final CloudBackend instance = CloudBackend._();

  bool _ready = false;
  bool get isReady => _ready;

  /// Consecutive failed media uploads. A single blip is silent; once this
  /// climbs past [uploadFailureHintAfter] the home screen shows a subtle
  /// "cloud sync unavailable" hint. Any successful upload resets it.
  final ValueNotifier<int> failedUploadStreak = ValueNotifier<int>(0);

  /// Human-readable description of the last upload failure, shown in the
  /// home-screen hint so the user knows *why* sync is failing.
  final ValueNotifier<String> lastUploadError = ValueNotifier<String>('');

  /// Threshold for the home-screen "cloud sync unavailable" hint.
  static const int uploadFailureHintAfter = 3;

  /// Max retries for a single upload before giving up.
  static const int uploadMaxRetries = 3;

  /// Base delay between retries (doubles each attempt).
  static const Duration uploadRetryBaseDelay = Duration(seconds: 2);

  /// Supabase client shorthand.
  supa.SupabaseClient get _db => supa.Supabase.instance.client;
  supa.SupabaseStorageClient get _storage => _db.storage;

  /// Runs [op], resetting [failedUploadStreak] on success and incrementing it
  /// on failure (rethrow). Early no-op returns (e.g. Supabase not configured)
  /// never count — the app is expected to be fully offline then.
  Future<T> _trackUpload<T>(Future<T> Function() op) async {
    try {
      final result = await op();
      if (failedUploadStreak.value > 0) failedUploadStreak.value = 0;
      return result;
    } catch (_) {
      failedUploadStreak.value++;
      rethrow;
    }
  }

  // ------------------------------------------------------------------ Init --

  /// Initialises Firebase + Supabase. Returns true only when Supabase is
  /// configured (Firebase failures are non-fatal — the app still works
  /// offline).
  Future<bool> initialize() async {
    // Firebase (auth, analytics, crashlytics, messaging).
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _activateAppCheck();
    } catch (e) {
      AppLogger.warning(
        'Firebase init failed (continuing without it)',
        error: e,
      );
    }

    // Supabase (database + storage).
    if (SupabaseConfig.isConfigured) {
      try {
        await supa.Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
        );
        _ready = true;
      } catch (e) {
        AppLogger.error('Supabase init failed', error: e);
        _ready = false;
      }
    } else {
      debugPrint('CloudBackend: Supabase not configured — running offline');
      _ready = false;
    }
    return _ready;
  }

  Future<void> _activateAppCheck() async {
    if (kIsWeb) return;
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    } catch (e) {
      AppLogger.warning('App Check activation failed (continuing)', error: e);
    }
  }

  // ------------------------------------------------------------------ Auth --
  // Firebase Auth remains untouched — it's free up to 50K MAU.

  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();

  User? get currentUser => FirebaseAuth.instance.currentUser;

  String get currentUid => currentUser?.uid ?? '';

  Future<User?> signInWithEmail(String email, String password) async {
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Also create a Supabase session so Storage uploads are authenticated.
    // Uses a deterministic password so re-auth works without storing the
    // user's actual password.
    await _ensureSupabaseAuth(email, _socialPassword(email));
    return cred.user;
  }

  Future<User?> createAccount(String email, String password) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Mirror the account in Supabase so Storage uploads are authenticated.
    await _ensureSupabaseAuth(email, _socialPassword(email));
    return cred.user;
  }

  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      // On web, use Firebase Auth's popup/redirect — the google_sign_in
      // package's authenticate() is not supported on web.
      try {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.setCustomParameters({'prompt': 'select_account'});
        final cred = await FirebaseAuth.instance.signInWithPopup(provider);
        final email = cred.user?.email;
        if (email != null) {
          await _ensureSupabaseAuth(email, _socialPassword(email));
        }
        return cred.user;
      } catch (e) {
        debugPrint('Google sign-in popup error: $e');
        return null;
      }
    }
    // Mobile: use google_sign_in package
    try {
      await GoogleSignIn.instance.initialize(
        clientId:
            '629393260589-kdn446mj2thdkk4klnvsve01ho2pirt1.apps.googleusercontent.com',
      );
    } catch (_) {}
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      debugPrint(
        'GoogleSignInException: ${e.code} — ${e.description} — ${e.details}',
      );
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) return null;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final cred = await FirebaseAuth.instance.signInWithCredential(credential);
    final email = cred.user?.email;
    if (email != null) {
      await _ensureSupabaseAuth(email, _socialPassword(email));
    }
    // Authenticate Google Drive for private vault storage.
    await GoogleDriveService.instance.authenticate();
    return cred.user;
  }

  Future<User?> signInWithApple({
    required String idToken,
    required String? rawNonce,
  }) async {
    final oauth = OAuthProvider(
      'apple.com',
    ).credential(idToken: idToken, rawNonce: rawNonce);
    final cred = await FirebaseAuth.instance.signInWithCredential(oauth);
    // Mirror Apple account in Supabase for Storage auth.
    final email = cred.user?.email;
    if (email != null) {
      await _ensureSupabaseAuth(email, _socialPassword(email));
    }
    return cred.user;
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw Exception('You must be signed in to change your password.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    // Clear Google Drive credentials.
    GoogleDriveService.instance.signOut();
    // Sign out of Supabase too.
    try {
      await _db.auth.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  /// After Firebase auth, create a matching Supabase session so Storage
  /// uploads are authenticated. If the Supabase account doesn't exist yet,
  /// create it automatically.
  Future<void> _ensureSupabaseAuth(String email, String password) async {
    if (!_ready) return;
    // Already authenticated?
    final current = _db.auth.currentUser;
    if (current != null && current.email == email) return;
    try {
      await _db.auth.signInWithPassword(email: email, password: password);
      AppLogger.info('Supabase auth session created for $email');
    } catch (_) {
      // Supabase account may not exist — create it silently.
      try {
        await _db.auth.signUp(email: email, password: password);
        AppLogger.info('Supabase account created for $email');
      } catch (e) {
        AppLogger.warning('Supabase auth failed for $email', error: e);
      }
    }
  }

  /// Deterministic password for social-login Supabase accounts.
  /// Derived from the email so the same email always maps to the same
  /// password across sign-in and sign-up calls.
  static String _socialPassword(String email) =>
      'av_${email.hashCode.toRadixString(16)}_sync';

  /// Ensures the Supabase client has an active auth session before storage
  /// operations. Re-authenticates silently using the Firebase user info.
  Future<void> _refreshSupabaseSession() async {
    if (!_ready) return;
    final current = _db.auth.currentUser;
    if (current != null) return; // already authenticated
    // No Supabase session — try to create one from the Firebase user.
    final fbUser = currentUser;
    if (fbUser == null || fbUser.email == null) return;
    await _ensureSupabaseAuth(fbUser.email!, _socialPassword(fbUser.email!));
  }

  // -------------------------------------------------------------- Supabase DB --

  /// Upserts a row into [collection] (Supabase table) keyed by [pk].
  Future<void> upsert(
    String collection,
    String id,
    Map<String, dynamic> data, {
    String pk = 'id',
  }) async {
    if (!_ready) return;
    await _db.from(collection).upsert({...data, pk: id});
  }

  /// Deletes a row from [collection] by [pk].
  Future<void> remove(String collection, String id, {String pk = 'id'}) async {
    if (!_ready) return;
    await _db.from(collection).delete().eq(pk, id);
  }

  /// Inserts a row with an auto-generated id.
  Future<void> addDoc(String collection, Map<String, dynamic> data) async {
    if (!_ready) return;
    await _db.from(collection).insert(data);
  }

  /// Removes a single field by setting it to null.
  Future<void> deleteField(
    String collection,
    String id,
    String field, {
    String pk = 'id',
  }) async {
    if (!_ready) return;
    await _db.from(collection).update({field: null}).eq(pk, id);
  }

  /// Calls a Postgres RPC (atomic DB function) — used for revoke/update_role.
  Future<void> rpc(String fn, Map<String, dynamic> params) async {
    if (!_ready) throw Exception('Supabase not ready');
    await _db.rpc(fn, params: params);
  }

  /// Fetches every row in [collection]. Pass [owner] to filter by ownerUid.
  Future<List<Map<String, dynamic>>> fetchAll(
    String collection, {
    String? owner,
  }) async {
    if (!_ready) return const [];
    supa.PostgrestFilterBuilder query = _db.from(collection).select();
    if (owner != null && owner.isNotEmpty) {
      query = query.eq('ownerUid', owner);
    }
    final data = await query;
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetches a single row by [pk], or null when it doesn't exist.
  Future<Map<String, dynamic>?> fetchDoc(
    String collection,
    String id, {
    String pk = 'id',
  }) async {
    if (!_ready) return null;
    try {
      final data = await _db.from(collection).select().eq(pk, id).single();
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null; // not found or error
    }
  }

  /// Live stream of every row in [collection].
  Stream<List<Map<String, dynamic>>> watchCollection(
    String collection, {
    String pk = 'id',
  }) {
    if (!_ready) return const Stream.empty();
    return _db
        .from(collection)
        .stream(primaryKey: [pk])
        .map((list) => list.cast<Map<String, dynamic>>());
  }

  /// Live list of every registered user's profile.
  Stream<List<Map<String, dynamic>>> watchUsers() =>
      watchCollection('users', pk: 'uid');

  /// Live stream of a single row.
  Stream<Map<String, dynamic>?> watchDoc(
    String collection,
    String id, {
    String pk = 'id',
  }) {
    if (!_ready) return const Stream.empty();
    return _db
        .from(collection)
        .stream(primaryKey: [pk])
        .eq(pk, id)
        .map((list) => list.isEmpty ? null : list.first);
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async => fetchAll('users');

  // ---------------------------------------------------------- Cloud Storage --
  // Upload order: Google Drive → Supabase Storage → Firebase Storage.
  // Download order: Google Drive file ID → Supabase URL → HTTPS allow-list.
  // Public URLs always use Firebase Storage (Drive files can't be hotlinked).

  /// Maximum upload size in bytes (50 MB — Supabase free plan limit).
  static const int maxUploadBytes = 50 * 1024 * 1024;

  /// Google Drive is the primary file storage when the user is signed in
  /// with Google. Returns true when Drive is available for uploads.
  bool get _driveReady => GoogleDriveService.instance.isReady;

  /// Uploads bytes to cloud storage and returns a download URL.
  ///
  /// Priority: Google Drive (user's own 15 GB) → Supabase → Firebase.
  /// For public-facing images (galleries), callers should also push a copy
  /// to Firebase Storage via [uploadToFirebasePublic] since Drive files
  /// cannot be hotlinked.
  Future<String?> uploadBytes(
    String path,
    Uint8List bytes, {
    String? contentType,
  }) async {
    // --- 1. Try Google Drive first ---
    if (_driveReady) {
      try {
        final driveId = await GoogleDriveService.instance.uploadBytes(
          drivePath: path,
          bytes: bytes,
          contentType: contentType ?? 'image/jpeg',
        );
        if (driveId != null) {
          // Return a Drive file ID marker — downloadBytes recognises this prefix.
          final driveRef = 'gdrive:$driveId';
          AppLogger.info('uploadBytes: Google Drive success → $driveRef');
          lastUploadError.value = '';
          if (failedUploadStreak.value > 0) failedUploadStreak.value = 0;
          return driveRef;
        }
      } catch (e) {
        AppLogger.warning(
          'uploadBytes: Google Drive failed, falling back',
          error: e,
        );
      }
    }

    // --- 2. Try Supabase Storage ---
    if (_ready) {
      await _refreshSupabaseSession();
      if (bytes.length > maxUploadBytes) {
        AppLogger.warning(
          'uploadBytes: file exceeds Supabase 50 MB limit — skipping Supabase',
        );
      } else {
        for (var attempt = 1; attempt <= uploadMaxRetries; attempt++) {
          try {
            return await _trackUpload(() async {
              final bucket = _bucketForPath(path);
              AppLogger.info(
                'uploadBytes: Supabase attempt $attempt/$uploadMaxRetries — $bucket/${_stripBucket(path)} (${bytes.length} bytes)',
              );
              await _storage
                  .from(bucket)
                  .uploadBinary(
                    _stripBucket(path),
                    bytes,
                    fileOptions: supa.FileOptions(
                      contentType: contentType ?? 'image/jpeg',
                      upsert: true,
                    ),
                  );
              final url = _storage
                  .from(bucket)
                  .getPublicUrl(_stripBucket(path));
              AppLogger.info('uploadBytes: Supabase success → $url');
              return url;
            });
          } catch (e) {
            final msg = _friendlyError(e);
            lastUploadError.value = msg;
            AppLogger.warning(
              'uploadBytes: Supabase attempt $attempt/$uploadMaxRetries FAILED — $msg',
            );
            if (attempt < uploadMaxRetries) {
              final delay = uploadRetryBaseDelay * (1 << (attempt - 1));
              await Future<void>.delayed(delay);
              await _refreshSupabaseSession();
            }
          }
        }
      }
    }

    // --- 3. Firebase Storage fallback ---
    AppLogger.info('uploadBytes: trying Firebase Storage fallback…');
    try {
      final url = await _uploadToFirebase(path, bytes, contentType);
      if (url != null) {
        AppLogger.info('uploadBytes: Firebase Storage success → $url');
        lastUploadError.value = '';
        if (failedUploadStreak.value > 0) failedUploadStreak.value = 0;
        return url;
      }
    } catch (fbError) {
      AppLogger.warning(
        'uploadBytes: Firebase fallback also failed',
        error: fbError,
      );
    }
    throw Exception(
      lastUploadError.value.isNotEmpty
          ? lastUploadError.value
          : 'All storage backends failed',
    );
  }

  /// Uploads bytes to Firebase Storage directly (for public-facing images
  /// that need a hotlinkable URL, e.g. gallery pages).
  Future<String?> uploadToFirebasePublic(
    String path,
    Uint8List bytes, {
    String? contentType,
  }) async {
    return _uploadToFirebase(path, bytes, contentType);
  }

  /// Uploads bytes and returns a public URL (same as [uploadBytes]).
  Future<String?> uploadBytesPublic(
    String path,
    Uint8List bytes, {
    String? contentType,
  }) async {
    return uploadBytes(path, bytes, contentType: contentType);
  }

  /// Returns the public download URL for [path] without uploading.
  /// For Drive files, returns null (Drive files can't be hotlinked).
  String? publicUrlFor(String path) {
    if (!_ready) return null;
    final bucket = _bucketForPath(path);
    return _storage.from(bucket).getPublicUrl(_stripBucket(path));
  }

  /// Downloads bytes from cloud storage.
  ///
  /// Recognises three URL/ref formats:
  /// - `gdrive:{fileId}` — Google Drive file ID (primary)
  /// - Supabase Storage URL (`/storage/v1/object/`)
  /// - Allow-listed HTTPS URLs
  Future<Uint8List?> downloadBytes(String url) async {
    if (url.isEmpty) return null;

    // --- Google Drive file ID ---
    if (url.startsWith('gdrive:')) {
      final fileId = url.substring(7);
      if (_driveReady) {
        return GoogleDriveService.instance.downloadBytes(fileId);
      }
      return null;
    }

    // --- Supabase / HTTPS ---
    if (!_ready) return null;
    try {
      if (url.contains('/storage/v1/object/')) {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        final bucketIdx = segments.indexOf('object') + 2;
        final bucket = segments[bucketIdx];
        final objectPath = segments.sublist(bucketIdx + 1).join('/');
        final data = await _storage.from(bucket).download(objectPath);
        return data;
      }
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') return null;
      const allowedSuffixes = [
        '.supabase.co',
        '.supabase.in',
        '.googleapis.com',
        '.gstatic.com',
        '.cloudfunctions.net',
        '.firebaseio.com',
      ];
      final host = uri.host.toLowerCase();
      final allowed =
          allowedSuffixes.any((s) => host.endsWith(s)) ||
          host == 'mtwinlbgvuxezadbsrrl.supabase.co';
      if (!allowed) return null;
      if (RegExp(
        r'^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|127\.|169\.254\.|::1)',
      ).hasMatch(host)) {
        return null;
      }
      final resp = await http.get(uri);
      if (resp.statusCode == 200) return resp.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Deletes a file from cloud storage.
  /// Handles Google Drive refs, Supabase paths, and Firebase paths.
  Future<void> deleteFile(String path) async {
    // Google Drive file ID
    if (path.startsWith('gdrive:')) {
      final fileId = path.substring(7);
      if (_driveReady) {
        await GoogleDriveService.instance.deleteFile(fileId);
      }
      return;
    }
    // Supabase Storage
    if (_ready) {
      try {
        final bucket = _bucketForPath(path);
        await _storage.from(bucket).remove([_stripBucket(path)]);
      } catch (_) {}
    }
  }

  /// Maps a storage path to the correct Supabase bucket.
  String _bucketForPath(String path) {
    if (path.startsWith('profile/')) return SupabaseConfig.bucketProfile;
    if (path.startsWith('paintings/')) return SupabaseConfig.bucketPaintings;
    if (path.startsWith('documents/')) return SupabaseConfig.bucketDocuments;
    // Default: try paintings bucket
    return SupabaseConfig.bucketPaintings;
  }

  /// Strips the bucket prefix from a path.
  /// "paintings/abc123/photo.jpg" → "abc123/photo.jpg"
  String _stripBucket(String path) {
    final parts = path.split('/');
    if (parts.length > 1) return parts.sublist(1).join('/');
    return path;
  }

  // -------------------------------------------------------------- Messaging --

  Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> requestNotificationsPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
  }

  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (_) {}
  }

  // -------------------------------------------------------------- Analytics --

  void logEvent(String name, [Map<String, Object?>? parameters]) {
    try {
      FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters?.cast<String, Object>(),
      );
    } catch (_) {}
  }

  void logError(Object error, StackTrace stackTrace) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    } catch (_) {}
  }

  void setUser(String uid, String email) {
    try {
      FirebaseCrashlytics.instance.setUserIdentifier(uid);
      FirebaseAnalytics.instance.setUserId(id: uid);
      FirebaseAnalytics.instance.logEvent(name: 'user_login');
    } catch (_) {}
  }

  /// Uploads bytes to Firebase Storage as a fallback when Supabase fails.
  Future<String?> _uploadToFirebase(
    String path,
    Uint8List bytes,
    String? contentType,
  ) async {
    try {
      final ref = fb_storage.FirebaseStorage.instance.ref().child(path);
      final metadata = fb_storage.SettableMetadata(
        contentType: contentType ?? 'image/jpeg',
      );
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      AppLogger.warning('Firebase upload failed for $path', error: e);
      return null;
    }
  }

  /// Converts a raw Supabase/storage exception into a user-friendly message.
  static String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('DatabaseSchemaMismatch')) {
      return 'Cloud storage needs setup — run the migration SQL in your Supabase dashboard.';
    }
    if (raw.contains('statusCode: 413') || raw.contains('File too large')) {
      return 'File too large for cloud storage (max 50 MB).';
    }
    if (raw.contains('statusCode: 403') || raw.contains('Forbidden')) {
      return 'Permission denied — check your account access.';
    }
    if (raw.contains('SocketException') || raw.contains('Connection refused')) {
      return 'Network error — check your internet connection.';
    }
    if (raw.contains('TimeoutException') || raw.contains('timeout')) {
      return 'Upload timed out — check your connection and try again.';
    }
    if (raw.contains('401') || raw.contains('Unauthorized')) {
      return 'Session expired — signing in again.';
    }
    // Truncate long error messages for display.
    final short = raw.length > 120 ? '${raw.substring(0, 117)}...' : raw;
    return 'Upload failed: $short';
  }
}
