import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/app_constants.dart';
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
    } catch (_) {
      _ready = false;
    }
    return _ready;
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
    // Prefer the backend-mediated sender: a Cloud Function generates the
    // official Firebase reset link and delivers it through the project's own
    // SMTP (so it lands in the inbox instead of spam). It can also tell us
    // honestly whether the account exists (the client can't — Firebase's
    // email-enumeration protection masks it). Falls back to Firebase's
    // built-in sender only when the function isn't deployed/reachable.
    final backendHandled = await _sendPasswordResetViaBackend(email);
    if (backendHandled) return;
    // NOTE: with email-enumeration protection enabled (the default for
    // projects created after Sep 2023), Firebase intentionally returns
    // success for unknown addresses without sending anything, and
    // fetchSignInMethodsForEmail returns an empty list even for existing
    // users — so an existence pre-check is impossible client-side. We
    // therefore ask Firebase to send and let the user verify delivery;
    // the surrounding UI tells them to check spam/junk if nothing arrives.
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  /// Calls the `sendPasswordReset` Cloud Function.
  ///
  /// Returns `true` when the backend answered (success OR an authoritative
  /// error that should be surfaced to the user), and `false` when it is
  /// unreachable (function not deployed, network down) so the caller can fall
  /// back to Firebase's built-in sender.
  Future<bool> _sendPasswordResetViaBackend(String email) async {
    try {
      final resp = await http
          .post(
            Uri.parse(AppConstants.resetBackendUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 20));
      // Cloud Functions answers with JSON {ok, error}. Anything else (e.g. an
      // HTML 404 from the platform) means the function isn't deployed yet.
      final decoded = _tryDecodeJson(resp.body);
      if (decoded == null) return false;
      if (resp.statusCode == 200 && decoded['ok'] == true) return true;
      throw Exception(
        (decoded['error'] as String?) ??
            'Could not send the reset email. Please try again.',
      );
    } on TimeoutException {
      return false;
    } on http.ClientException {
      // DNS / connection failure — the function isn't reachable.
      return false;
    }
  }

  static Map<String, dynamic>? _tryDecodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
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
