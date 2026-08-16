import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/face_debug_log.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/app_user.dart';
import '../../data/remote/cloud_backend.dart';
import '../local/local_database.dart';

/// Authentication + session + RBAC role management.
///
/// Session credentials (Google token, remember-me flag) live in the OS
/// secure storage; the user profile is cached in Hive for offline boot.
class AuthRepository {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  AppUser get cachedUser {
    final raw = LocalDatabase.instance.getById(AppConstants.boxProfile, 'me');
    return raw == null ? AppUser.placeholder() : AppUser.fromJson(raw);
  }

  Future<void> _persistUser(AppUser user) async {
    await LocalDatabase.instance.put(
      AppConstants.boxProfile,
      'me',
      user.toJson(),
    );
    await LocalDatabase.instance.setSetting(AppConstants.kSessionUid, user.uid);
    CloudBackend.instance.setUser(user.uid, user.email);
  }

  // -------------------------------------------------------------- Session --

  Future<bool> get hasRememberedSession async {
    final remember = LocalDatabase.instance.getBool(AppConstants.kRememberMe);
    if (!remember) return false;
    final uid = await _secure.read(key: AppConstants.kSessionUid);
    return uid != null && uid.isNotEmpty;
  }

  Future<void> saveRememberedSession(String uid) async {
    await LocalDatabase.instance.setSetting(AppConstants.kRememberMe, true);
    await _secure.write(key: AppConstants.kSessionUid, value: uid);
  }

  Future<void> clearRememberedSession() async {
    await LocalDatabase.instance.setSetting(AppConstants.kRememberMe, false);
    await _secure.delete(key: AppConstants.kSessionUid);
  }

  // ------------------------------------------------------------------ Auth --

  Future<AppUser> signInWithEmail(
    String email,
    String password, {
    bool remember = false,
  }) async {
    final cloud = CloudBackend.instance;
    if (cloud.isReady) {
      final user = await cloud.signInWithEmail(email, password);
      if (user != null) {
        final profile = await _loadOrCreateProfile(user);
        if (remember) await saveRememberedSession(user.uid);
        await _persistUser(profile);
        return profile;
      }
    }
    throw AuthException('Unable to sign in. Please check your credentials.');
  }

  Future<AppUser> register(
    String name,
    String email,
    String password, {
    String? adminCode,
  }) async {
    final cloud = CloudBackend.instance;
    if (cloud.isReady) {
      final user = await cloud.createAccount(email, password);
      if (user != null) {
        await user.updateDisplayName(name);
        final wantsAdmin = adminCode != null && adminCode.isNotEmpty;
    final profile = AppUser(
      uid: user.uid,
      email: email,
      displayName: name,
      // With a valid bootstrap code the registering user becomes the very
      // first admin of the organisation; otherwise a curator. The rules
      // verify the code server-side, so a wrong/absent code can never
      // self-promote.
      role: wantsAdmin ? AppRole.admin : AppRole.curator,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    final data = Map<String, dynamic>.from(profile.toJson());
    if (wantsAdmin) {
      // The rules check this field against bootstrap/config.adminCode.
      data['bootstrapCode'] = adminCode;
    }
    await cloud.upsert('users', user.uid, data);
    if (wantsAdmin) {
      // Strip the one-time code so it never lingers in the profile doc.
      await cloud.deleteField('users', user.uid, 'bootstrapCode');
    }
        await _persistUser(profile);
        return profile;
      }
    }
    throw AuthException(
      'Registration is unavailable. Configure Firebase to enable accounts.',
    );
  }

  Future<AppUser> signInWithGoogle() async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady) {
      throw AuthException('Google sign-in needs Firebase to be configured.');
    }
    try {
      final user = await cloud.signInWithGoogle();
      if (user == null) throw AuthException('Google sign-in was cancelled.');
      final profile = await _loadOrCreateProfile(user);
      await _persistUser(profile);
      // Keep the session across restarts, like email sign-in does.
      await saveRememberedSession(user.uid);
      return profile;
    } on GoogleSignInException catch (e) {
      // Distinguish "user cancelled" from real configuration problems so the
      // login screen can show the actual cause instead of a misleading one.
      throw AuthException(switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not configured for this app yet. The Android app is '
              'missing its certificate fingerprint in the Firebase console, or a '
              'web client ID is missing. Contact the developer to fix it.',
        _ => 'Google sign-in failed. Please try again.',
      });
    }
  }

  Future<AppUser> signInWithApple() async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady) {
      throw AuthException('Apple sign-in needs Firebase to be configured.');
    }

    // OAuth nonce: send the SHA-256 hash to Apple, keep the raw value for
    // Firebase token exchange.
    final rawNonce = _generateNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: _sha256(rawNonce),
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw AuthException('Apple sign-in was cancelled.');
    }

    final user = await cloud.signInWithApple(
      idToken: idToken,
      rawNonce: rawNonce,
    );
    if (user == null) throw AuthException('Apple sign-in failed.');
    final profile = await _loadOrCreateProfile(user);
    await _persistUser(profile);
    // Keep the session across restarts, like email sign-in does.
    await saveRememberedSession(user.uid);
    return profile;
  }

  /// Cryptographically secure random nonce for OAuth.
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256(String input) =>
      crypto.sha256.convert(utf8.encode(input)).toString();

  Future<void> sendPasswordReset(String email) =>
      CloudBackend.instance.sendPasswordReset(email);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => CloudBackend.instance.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  Future<AppUser> restoreSession() async {
    final cached = cachedUser;
    if (cached.uid.isEmpty) {
      throw AuthException('No saved session.');
    }
    // Prefer live Firebase user when available.
    final cloud = CloudBackend.instance;
    if (cloud.isReady) {
      final user = cloud.currentUser;
      if (user != null) {
        final profile = await _loadOrCreateProfile(user);
        await _persistUser(profile);
        return profile;
      }
    }
    return cached;
  }

  Future<void> signOut() async {
    await CloudBackend.instance.signOut();
    await clearRememberedSession();
    await LocalDatabase.instance.delete(AppConstants.boxProfile, 'me');
    await LocalDatabase.instance.setSetting(AppConstants.kSessionUid, '');
  }

  Future<AppUser> _loadOrCreateProfile(dynamic firebaseUser) async {
    final uid = firebaseUser.uid as String;
    final email = (firebaseUser.email as String?) ?? '';
    final name = (firebaseUser.displayName as String?) ?? 'ArtVault User';

    // A revoked account must not silently come back as a fresh curator.
    try {
      final revoked = await CloudBackend.instance.fetchDoc('revoked', uid);
      if (revoked != null) {
        throw AuthException(
          'This account has been revoked by an administrator.',
        );
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      // Offline / rules hiccup — fall through and try the profile lookup.
    }

    // Check Firestore for an existing profile (preserves assigned role).
    try {
      final profiles = await CloudBackend.instance.fetchAll('users');
      final match = profiles.where((m) => m['uid'] == uid).toList();
      if (match.isNotEmpty) {
        return AppUser.fromJson(
          match.first,
        ).copyWith(lastLogin: DateTime.now());
      }
    } catch (_) {}

    final profile = AppUser(
      uid: uid,
      email: email,
      displayName: name,
      role: AppRole.curator,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    await CloudBackend.instance.upsert('users', uid, profile.toJson());
    return profile;
  }

  // ------------------------------------------------------------------ RBAC --

  /// Persists a profile fetched from the cloud (live role/plan sync) into
  /// the local cache so the UI reflects remote changes immediately.
  Future<void> cacheRemoteUser(AppUser user) async {
    await LocalDatabase.instance.put(
      AppConstants.boxProfile,
      'me',
      user.toJson(),
    );
    CloudBackend.instance.setUser(user.uid, user.email);
  }

  Future<void> updateRole(String uid, AppRole role) async {
    final me = cachedUser;
    final oldRole = await _roleOf(uid);
    await CloudBackend.instance.upsert('users', uid, {'role': role.wire});
    // Audit the change: who did it, to whom, from what to what, when.
    try {
      await CloudBackend.instance.addDoc('role_audit', {
        'uid': uid,
        'byUid': me.uid,
        'byEmail': me.email,
        'oldRole': oldRole,
        'newRole': role.wire,
        'at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort: an audit write failure must never block a role change.
    }
    if (uid == cachedUser.uid) {
      await LocalDatabase.instance.put(
        AppConstants.boxProfile,
        'me',
        cachedUser.copyWith(role: role).toJson(),
      );
    }
  }

  /// Reads a user's current role from the cloud (best-effort; defaults to
  /// the previous local knowledge when offline).
  static Future<String> _roleOf(String uid) async {
    try {
      final doc = await CloudBackend.instance.fetchDoc('users', uid);
      if (doc != null && doc['role'] is String) return doc['role'] as String;
    } catch (_) {}
    return 'unknown';
  }

  /// Revokes a user entirely: deletes their profile document (their vault
  /// data stays in the cloud and re-syncs if the account is ever restored),
  /// leaves a `revoked/{uid}` marker so the rules refuse to re-create the
  /// profile, and signs them out remotely — the live profile watcher on
  /// their device sees the doc disappear and ends the session immediately.
  ///
  /// The marker keeps the name/email/role so an admin can later restore the
  /// account from the Users screen.
  Future<void> revokeUser(String uid, {String? email, String? displayName}) async {
    final me = cachedUser;
    final oldRole = await _roleOf(uid);
    await CloudBackend.instance.remove('users', uid);
    await CloudBackend.instance.upsert('revoked', uid, {
      'uid': uid,
      'email': email ?? '',
      'displayName': displayName ?? '',
      'role': oldRole,
      'revokedAt': DateTime.now().toIso8601String(),
      'byUid': me.uid,
      'byEmail': me.email,
    });
    // Audit the revocation like a role change, so the history shows it.
    try {
      await CloudBackend.instance.addDoc('role_audit', {
        'uid': uid,
        'byUid': me.uid,
        'byEmail': me.email,
        'oldRole': oldRole,
        'newRole': 'revoked',
        'at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort audit.
    }
    // Drop the local copy if this device happened to be that account.
    if (uid == cachedUser.uid) {
      await signOut();
    }
  }

  /// Restores a revoked account: removes the `revoked/{uid}` marker so the
  /// rules allow the profile to be re-created (curator) on their next
  /// sign-in, and logs the restore in the audit trail. Vault data was never
  /// deleted, so everything they owned re-syncs as before.
  Future<void> restoreUser(String uid) async {
    final me = cachedUser;
    // Remember the old role for the audit before deleting the marker.
    String oldRole = 'revoked';
    try {
      final marker = await CloudBackend.instance.fetchDoc('revoked', uid);
      if (marker != null && marker['role'] is String) {
        oldRole = marker['role'] as String;
      }
    } catch (_) {}
    await CloudBackend.instance.remove('revoked', uid);
    try {
      await CloudBackend.instance.addDoc('role_audit', {
        'uid': uid,
        'byUid': me.uid,
        'byEmail': me.email,
        'oldRole': oldRole,
        'newRole': 'restored',
        'at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort audit.
    }
  }

  /// Sets the subscription tier. Plan changes are admin-only in the rules,
  /// so a non-admin upgrade persists locally and the cloud write is
  /// best-effort (succeeds for admins; silently skipped otherwise). The
  /// local flag is what drives the UI, so upgrades work offline-first.
  Future<void> updatePlan(String uid, AppPlan plan) async {
    try {
      await CloudBackend.instance.upsert('users', uid, {'plan': plan.wire});
    } catch (_) {
      // Non-admin / offline: the cloud write is denied or skipped — keep
      // the local entitlement so the UI still reflects the upgrade.
    }
    if (uid == cachedUser.uid) {
      await LocalDatabase.instance.put(
        AppConstants.boxProfile,
        'me',
        cachedUser.copyWith(plan: plan).toJson(),
      );
    }
  }

  /// Updates the local + cloud copy of the signed-in profile.
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? photoPath,
    String? photoUrl,
    AppRole? role,
  }) async {
    final me = cachedUser;
    final updated = me.copyWith(
      displayName: displayName,
      bio: bio,
      photoPath: photoPath,
      photoUrl: photoUrl,
      role: role,
    );
    await LocalDatabase.instance.put(
      AppConstants.boxProfile,
      'me',
      updated.toJson(),
    );
    await CloudBackend.instance.upsert('users', me.uid, {
      'displayName': ?displayName,
      'bio': ?bio,
      'photoPath': ?photoPath,
      'photoUrl': ?photoUrl,
      if (role != null) 'role': role.wire,
    });
    CloudBackend.instance.setUser(me.uid, me.email);
  }

  // -------------------------------------------------------------- Biometrics --

  Future<bool> get biometricEnabled => Future.value(
    LocalDatabase.instance.getBool(AppConstants.kBiometricEnabled),
  );

  Future<void> setBiometricEnabled(bool enabled) async {
    // Check availability before persisting so a failed enable never leaves
    // the setting on (which would route the user to an unlockable App Lock).
    if (enabled && !(await BiometricService.instance.isAvailable)) {
      throw AuthException('Biometrics are not available on this device.');
    }
    await LocalDatabase.instance.setSetting(
      AppConstants.kBiometricEnabled,
      enabled,
    );
  }

  Future<bool> get faceLockEnabled => Future.value(
    LocalDatabase.instance.getBool(AppConstants.kFaceLockEnabled),
  );

  Future<void> setFaceLockEnabled(bool enabled) async {
    // Flag first — it's what routes the user to an unlockable App Lock — so
    // a secure-storage hiccup while deleting the embedding must never strand
    // the setting ON.
    await LocalDatabase.instance.setSetting(
      AppConstants.kFaceLockEnabled,
      enabled,
    );
    if (!enabled) {
      try {
        await clearFaceEmbedding();
      } catch (_) {
        // Best-effort cleanup; the flag is already off.
      }
    }
  }

  /// The enrolled owner face-embedding, or null when Face lock isn't set up.
  Future<List<double>?> get faceEmbedding async {
    final raw = await _secure.read(key: AppConstants.kFaceEmbedding);
    if (raw == null || raw.isEmpty) {
      await FaceDebugLog.instance.log('faceEmbedding read: null/empty');
      return null;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [for (final v in list) (v as num).toDouble()];
    } catch (_) {
      return null;
    }
  }

  Future<void> saveFaceEmbedding(List<double> embedding) async {
    // JSON cannot encode NaN/Infinity — sanitize first so a bad frame can
    // never silently break persistence.
    final clean = [for (final v in embedding) v.isFinite ? v : 0.0];
    final encoded = jsonEncode(clean);
    await FaceDebugLog.instance.log(
      'saveFaceEmbedding dims=${clean.length} chars=${encoded.length} '
      'nonZero=${clean.where((v) => v.abs() > 1e-4).length}',
    );
    await _secure.write(key: AppConstants.kFaceEmbedding, value: encoded);
    await FaceDebugLog.instance.log('saveFaceEmbedding write completed');
  }

  Future<void> clearFaceEmbedding() async {
    await _secure.delete(key: AppConstants.kFaceEmbedding);
  }

  Future<bool> verifyBiometric() => BiometricService.instance.authenticate();

  /// Verifies with fingerprint-only (strong) biometrics.
  Future<bool> verifyFingerprint() =>
      BiometricService.instance.authenticateFingerprint();

  /// Verifies with the face unlock method (system Face ID on iOS, in-app
  /// camera scan on Android — see [FaceAuthResult]).
  Future<FaceAuthResult> verifyFace() =>
      BiometricService.instance.authenticateFace();

  // ---------------------------------------------------------------- Passcode --

  /// True when a passcode has been set. Only a salted SHA-256 digest is kept
  /// in secure storage; the raw PIN never touches disk.
  Future<bool> get passcodeSet async {
    final hash = await _secure.read(key: AppConstants.kPasscodeHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Stores a new passcode as a salted SHA-256 digest.
  Future<void> setPasscode(String pin) async {
    final salt = _randomSalt();
    await _secure.write(
      key: AppConstants.kPasscodeHash,
      value: '$salt:${_digestPin(salt, pin)}',
    );
  }

  /// Verifies [pin] against the stored digest.
  Future<bool> verifyPasscode(String pin) async {
    final stored = await _secure.read(key: AppConstants.kPasscodeHash);
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return _digestPin(parts[0], pin) == parts[1];
  }

  /// Removes the stored passcode.
  Future<void> clearPasscode() async {
    await _secure.delete(key: AppConstants.kPasscodeHash);
  }

  static String _randomSalt() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _digestPin(String salt, String pin) =>
      crypto.sha256.convert(utf8.encode('$salt:$pin')).toString();

  // ------------------------------------------------------------------ Misc --

  Future<void> welcomeNotification() async {
    await NotificationService.instance.notify(
      'Welcome to ArtVault',
      'Your private art gallery is ready. Add your first painting to begin.',
      type: 'system',
    );
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
