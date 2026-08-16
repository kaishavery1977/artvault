import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';

/// Centralised gateway to all Firebase services.
///
/// The whole app degrades gracefully: if Firebase isn't configured, every
/// call here is a safe no-op and the app keeps working fully offline
/// (offline-first architecture). When configured, cloud sync lights up.
class CloudBackend {
  CloudBackend._();

  static final CloudBackend instance = CloudBackend._();

  bool _ready = false;
  bool get isReady => _ready;

  /// Attempts to initialise Firebase. Returns true only on success.
  Future<bool> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _ready = true;
      await _activateAppCheck();
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  /// Attests Android Firebase calls with App Check so requests carry a real
  /// token instead of a placeholder: debug builds use the debug provider
  /// (token auto-generated and printed to logcat — register it under
  /// Console → App Check → Manage debug tokens once enforcement is on),
  /// release builds use Play Integrity. Activation failures degrade to "no
  /// App Check" rather than taking the whole cloud offline; the web/desktop
  /// targets keep their defaults until a provider is configured for them.
  Future<void> _activateAppCheck() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
    } catch (e) {
      debugPrint('ArtVault: App Check activation failed (continuing): $e');
    }
  }

  // ------------------------------------------------------------------ Auth --

  Stream<User?> get authStateChanges =>
      _ready ? FirebaseAuth.instance.authStateChanges() : const Stream.empty();

  User? get currentUser => _ready ? FirebaseAuth.instance.currentUser : null;

  /// UID of the signed-in user (empty when offline / signed out).
  String get currentUid => currentUser?.uid ?? '';

  Future<User?> signInWithEmail(String email, String password) async {
    if (!_ready) return null;
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  Future<User?> createAccount(String email, String password) async {
    if (!_ready) return null;
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  Future<User?> signInWithGoogle() async {
    if (!_ready) return null;
    try {
      await GoogleSignIn.instance.initialize();
    } catch (_) {
      // authenticate() below will surface a meaningful error if setup is bad.
    }
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      debugPrint(
        'GoogleSignInException: ${e.code} — ${e.description} — ${e.details}',
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User backed out of the account picker — not an error.
        return null;
      }
      // Configuration / provider errors bubble up so the UI can explain them.
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
    if (!_ready) return null;
    final oauth = OAuthProvider(
      'apple.com',
    ).credential(idToken: idToken, rawNonce: rawNonce);
    final cred = await FirebaseAuth.instance.signInWithCredential(oauth);
    return cred.user;
  }

  Future<void> sendPasswordReset(String email) async {
    if (!_ready) {
      throw Exception(
        'Cloud is not connected. Sign in with an email account to reset your password.',
      );
    }
    // NOTE: with email-enumeration protection enabled (the default for
    // projects created after Sep 2023), Firebase intentionally returns
    // success for unknown addresses without sending anything, and
    // fetchSignInMethodsForEmail returns an empty list even for existing
    // users — so an existence pre-check is impossible client-side. We
    // therefore ask Firebase to send and let the user verify delivery;
    // the surrounding UI tells them to check spam/junk if nothing arrives.
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  /// Changes the signed-in user's password in-app (no email needed) after
  /// re-authenticating with the current password. Throws when the account
  /// has no password (e.g. Google-only) or the current password is wrong.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!_ready) {
      throw Exception(
        'Cloud is not connected. Sign in with an email account to change your password.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw Exception('You must be signed in to change your password.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    // Re-authentication is required before updating the password; this also
    // fails with a clear error when the account has no password set.
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    if (!_ready) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  // -------------------------------------------------------------- Firestore --

  Future<void> upsert(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (!_ready) return;
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(id)
        .set(data, SetOptions(merge: true));
  }

  Future<void> remove(String collection, String id) async {
    if (!_ready) return;
    await FirebaseFirestore.instance.collection(collection).doc(id).delete();
  }

  /// Appends a document with an auto-generated id (e.g. audit-log entries).
  Future<void> addDoc(String collection, Map<String, dynamic> data) async {
    if (!_ready) return;
    await FirebaseFirestore.instance.collection(collection).add(data);
  }

  /// Removes a single field from a document (used to strip the one-time
  /// bootstrap code after it has granted the first admin).
  Future<void> deleteField(String collection, String id, String field) async {
    if (!_ready) return;
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(id)
        .set({field: FieldValue.delete()}, SetOptions(merge: true));
  }

  /// Fetches every document in [collection]. Pass [owner] (a UID) to only
  /// fetch documents owned by that user — required under the owner-scoped
  /// Firestore rules.
  Future<List<Map<String, dynamic>>> fetchAll(
    String collection, {
    String? owner,
  }) async {
    if (!_ready) return const [];
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      collection,
    );
    if (owner != null && owner.isNotEmpty) {
      q = q.where('ownerUid', isEqualTo: owner);
    }
    final snap = await q.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Fetches a single document by id, or null when it doesn't exist.
  Future<Map<String, dynamic>?> fetchDoc(String collection, String id) async {
    if (!_ready) return null;
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .doc(id)
        .get();
    return snap.exists ? snap.data() : null;
  }

  Stream<List<Map<String, dynamic>>> watchCollection(String collection) {
    if (!_ready) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection(collection)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Live list of every registered user's profile (`users/{uid}`).
  Stream<List<Map<String, dynamic>>> watchUsers() => watchCollection('users');

  /// Live stream of a single document, e.g. `users/{uid}` so a role change
  /// made by an admin applies on the target device immediately instead of
  /// waiting for the next sign-in.
  Stream<Map<String, dynamic>?> watchDoc(String collection, String id) {
    if (!_ready) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection(collection)
        .doc(id)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async => fetchAll('users');

  // --------------------------------------------------------------- Storage --

  Future<String?> uploadBytes(
    String path,
    Uint8List bytes, {
    String? contentType,
  }) async {
    if (!_ready) return null;
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType ?? 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      ),
    );
    return ref.getDownloadURL();
  }

  /// Uploads bytes and returns a **rules-gated** plain download URL (no
  /// Firebase download token). Unlike [uploadBytes] — whose `getDownloadURL`
  /// embeds a token that bypasses storage security rules — this URL is
  /// evaluated against the rules on every request, so revoking or expiring
  /// the object's access actually stops it resolving. The page is served
  /// uncached so a revoked link can't linger in a browser/CDN cache.
  Future<String?> uploadBytesPublic(
    String path,
    Uint8List bytes, {
    String? contentType,
  }) async {
    if (!_ready) return null;
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType ?? 'text/html; charset=utf-8',
        cacheControl: 'private, no-store',
      ),
    );
    return publicUrlFor(path);
  }

  /// The plain (untokenized) download URL for [path]; reads against it are
  /// subject to storage security rules.
  String? publicUrlFor(String path) {
    if (!_ready) return null;
    return rulesGatedUrl(FirebaseStorage.instance.bucket, path);
  }

  /// Pure builder for a rules-gated media URL (testable without Firebase).
  static String rulesGatedUrl(String bucket, String path) =>
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o/'
      '${Uri.encodeComponent(path)}?alt=media';

  Future<void> deleteFile(String path) async {
    if (!_ready) return;
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } catch (_) {
      // File may already be gone — ignore.
    }
  }

  // -------------------------------------------------------------- Messaging --

  Future<String?> getFcmToken() async {
    if (!_ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> requestNotificationsPermission() async {
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      // ignored
    }
  }

  Stream<RemoteMessage> get onMessage =>
      _ready ? FirebaseMessaging.onMessage : const Stream.empty();

  Future<void> subscribeToTopic(String topic) async {
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (_) {}
  }

  // -------------------------------------------------------------- Analytics --

  void logEvent(String name, [Map<String, Object?>? parameters]) {
    if (!_ready) return;
    try {
      FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters?.cast<String, Object>(),
      );
    } catch (_) {}
  }

  void logError(Object error, StackTrace stackTrace) {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    } catch (_) {}
  }

  void setUser(String uid, String email) {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.setUserIdentifier(uid);
      FirebaseAnalytics.instance.setUserId(id: uid);
      FirebaseAnalytics.instance.logEvent(
        name: 'user_login',
        parameters: {'email': email},
      );
    } catch (_) {}
  }
}
