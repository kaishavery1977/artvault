// ignore_for_file: deprecated_member_use
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart'
    show ValueNotifier, debugPrint, kDebugMode, kIsWeb;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../core/config/supabase_config.dart';
import '../../core/services/app_logger.dart';
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

  /// Threshold for the home-screen "cloud sync unavailable" hint.
  static const int uploadFailureHintAfter = 3;

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
    return cred.user;
  }

  Future<User?> createAccount(String email, String password) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  Future<User?> signInWithGoogle() async {
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
    await FirebaseAuth.instance.signOut();
  }

  // -------------------------------------------------------------- Supabase DB --

  /// Upserts a row into [collection] (Supabase table) keyed by `id`.
  Future<void> upsert(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (!_ready) return;
    await _db.from(collection).upsert({...data, 'id': id});
  }

  /// Deletes a row from [collection] by `id`.
  Future<void> remove(String collection, String id) async {
    if (!_ready) return;
    await _db.from(collection).delete().eq('id', id);
  }

  /// Inserts a row with an auto-generated id.
  Future<void> addDoc(String collection, Map<String, dynamic> data) async {
    if (!_ready) return;
    await _db.from(collection).insert(data);
  }

  /// Removes a single field by setting it to null.
  Future<void> deleteField(String collection, String id, String field) async {
    if (!_ready) return;
    await _db.from(collection).update({field: null}).eq('id', id);
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

  /// Fetches a single row by id, or null when it doesn't exist.
  Future<Map<String, dynamic>?> fetchDoc(String collection, String id) async {
    if (!_ready) return null;
    try {
      final data = await _db.from(collection).select().eq('id', id).single();
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null; // not found or error
    }
  }

  /// Live stream of every row in [collection].
  Stream<List<Map<String, dynamic>>> watchCollection(String collection) {
    if (!_ready) return const Stream.empty();
    return _db
        .from(collection)
        .stream(primaryKey: ['id'])
        .map((list) => list.cast<Map<String, dynamic>>());
  }

  /// Live list of every registered user's profile.
  Stream<List<Map<String, dynamic>>> watchUsers() => watchCollection('users');

  /// Live stream of a single row.
  Stream<Map<String, dynamic>?> watchDoc(String collection, String id) {
    if (!_ready) return const Stream.empty();
    return _db
        .from(collection)
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((list) => list.isEmpty ? null : list.first);
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async => fetchAll('users');

  // ---------------------------------------------------------- Supabase Storage --

  /// Maximum upload size in bytes (50 MB — Supabase free plan limit).
  static const int maxUploadBytes = 50 * 1024 * 1024;

  /// Uploads bytes to Supabase Storage and returns the public download URL.
  Future<String?> uploadBytes(
    String path,
    Uint8List bytes, {
    String? contentType,
  }) async {
    if (!_ready) return null;
    // Enforce free-plan 50 MB limit client-side before hitting the network.
    if (bytes.length > maxUploadBytes) {
      throw Exception(
        'File is ${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB '
        '— maximum is 50 MB on the free plan.',
      );
    }
    return _trackUpload(() async {
      final bucket = _bucketForPath(path);
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
      return _storage.from(bucket).getPublicUrl(_stripBucket(path));
    });
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
  String? publicUrlFor(String path) {
    if (!_ready) return null;
    final bucket = _bucketForPath(path);
    return _storage.from(bucket).getPublicUrl(_stripBucket(path));
  }

  /// Downloads bytes from a Supabase Storage path or an allow-listed HTTPS URL.
  /// Non-allow-listed hosts and plain-http are rejected — prevents the
  /// on-device SSRF where a poisoned `photoUrl` in the DB could make the
  /// app fetch `http://169.254.169.254/` or other private targets.
  Future<Uint8List?> downloadBytes(String url) async {
    if (!_ready || url.isEmpty) return null;
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
      // Allow-list: only Supabase project + Google storage/CDN hosts.
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
      // Block private/link-local/metadata IPs even if host was spoofed via DNS.
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

  Future<void> deleteFile(String path) async {
    if (!_ready) return;
    try {
      final bucket = _bucketForPath(path);
      await _storage.from(bucket).remove([_stripBucket(path)]);
    } catch (_) {}
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
}
