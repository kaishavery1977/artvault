import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:crypto/crypto.dart' as crypto;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/face_debug_log.dart';
import '../../core/services/file_storage_service.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/app_user.dart';
import '../../data/remote/cloud_backend.dart';
import '../local/local_database.dart';
import '../../core/providers/data_providers.dart';

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
    try {
      final user = await cloud.signInWithEmail(email, password);
      if (user != null) {
        final profile = await _loadOrCreateProfile(user);
        // Always persist session UID for HMAC key consistency, even
        // when "remember me" is off — the face-embedding HMAC key
        // depends on this value being available on cold starts.
        await saveRememberedSession(user.uid);
        await _persistUser(profile);
        return profile;
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
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
    try {
      final user = await cloud.createAccount(email, password);
      if (user != null) {
        await user.updateDisplayName(name);
        final wantsAdmin = adminCode != null && adminCode.isNotEmpty;
        final profile = AppUser(
          uid: user.uid,
          email: email,
          displayName: name,
          role: wantsAdmin ? AppRole.admin : AppRole.curator,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        );
        final data = Map<String, dynamic>.from(profile.toFirestoreJson());
        if (wantsAdmin) {
          data['bootstrapCode'] = adminCode;
        }
        await cloud.upsert('users', user.uid, data, pk: 'uid');
        if (wantsAdmin) {
          await cloud.deleteField('users', user.uid, 'bootstrapCode', pk: 'uid');
        }
        await _persistUser(profile);
        return profile;
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    }
    throw AuthException(
      'Registration failed. Please try a different email or check Firebase configuration.',
    );
  }

  Future<AppUser> signInWithGoogle() async {
    final cloud = CloudBackend.instance;
    try {
      final user = await cloud.signInWithGoogle();
      if (user == null) throw AuthException('Google sign-in was cancelled.');
      final profile = await _loadOrCreateProfile(user);
      await _persistUser(profile);
      await saveRememberedSession(user.uid);
      return profile;
    } on AuthException {
      rethrow;
    } on GoogleSignInException catch (e) {
      throw AuthException(switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not configured for this app yet. The Android app is '
              'missing its SHA-1/SHA-256 fingerprint in the Firebase console, or a '
              'web client ID is missing. Add it under Project Settings → Your apps.',
        GoogleSignInExceptionCode.canceled => 'Google sign-in was cancelled.',
        _ => 'Google sign-in failed. Please try again.',
      });
    } catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    }
  }

  Future<AppUser> signInWithApple() async {
    final cloud = CloudBackend.instance;
    try {
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
      await saveRememberedSession(user.uid);
      return profile;
    } on AuthException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('AuthorizationErrorCode.canceled')) {
        throw AuthException('Apple sign-in was cancelled.');
      }
      throw AuthException(_friendlyAuthMessage(e));
    }
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
      // Fallback: the profile might not be in Hive yet (cold start race),
      // but the session UID may exist in secure storage from a previous
      // remember-me login.  Try to recover the session via Firebase Auth.
      final savedUid = await _secure.read(key: AppConstants.kSessionUid);
      if (savedUid == null || savedUid.isEmpty) {
        throw AuthException('No saved session.');
      }
      // Profile missing from Hive but UID exists — persist the UID so
      // HMAC key derivation is consistent on next read.
      await LocalDatabase.instance.setSetting(AppConstants.kSessionUid, savedUid);
      // Try Firebase Auth to rebuild the profile.
      final cloud = CloudBackend.instance;
      if (cloud.isReady) {
        final user = cloud.currentUser;
        if (user != null) {
          try {
            final profile = await _loadOrCreateProfile(user);
            await _persistUser(profile);
            return profile;
          } catch (_) {
            // Profile rebuild failed — return a minimal user so the
            // session is not lost.
            return AppUser(
              uid: savedUid,
              email: '',
              displayName: 'User',
              role: AppRole.curator,
              createdAt: DateTime.now(),
              lastLogin: DateTime.now(),
            );
          }
        }
      }
      // Firebase not ready yet — return minimal user with the saved UID.
      return AppUser(
        uid: savedUid,
        email: '',
        displayName: 'User',
        role: AppRole.curator,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
    }
    // Profile exists in Hive — persist UID for HMAC consistency.
    await LocalDatabase.instance.setSetting(AppConstants.kSessionUid, cached.uid);
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
      final revoked = await CloudBackend.instance.fetchDoc('revoked', uid, pk: 'uid');
      if (revoked != null) {
        throw AuthException(
          'This account has been revoked by an administrator.',
        );
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      // Offline / rules hiccup — fall through and try the profile lookup.
    }

    // Check Firestore for an existing profile (preserves assigned role and
    // plan). The profile is fetched by its own document id — an owner-scoped
    // read the rules allow for every signed-in user — rather than by
    // enumerating the `users` collection (which only admins may do) and
    // never by re-creating the profile from defaults (which would clobber
    // an existing role/plan and is rejected by the rules for Pro/admin).
    try {
      final doc = await CloudBackend.instance.fetchDoc('users', uid, pk: 'uid');
      if (doc != null && doc['uid'] == uid) {
        return AppUser.fromJson(doc).copyWith(lastLogin: DateTime.now());
      }
    } catch (e) {
      debugPrint(
        'AuthRepository._loadOrCreateProfile: fetchDoc failed ($e), creating new profile',
      );
    }

    final profile = AppUser(
      uid: uid,
      email: email,
      displayName: name,
      role: AppRole.curator,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    await CloudBackend.instance.upsert('users', uid, profile.toFirestoreJson(), pk: 'uid');
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
    // Atomic RPC closes TOCTOU: read+write+audits in one transaction.
    try {
      await CloudBackend.instance.rpc('update_role_atomic', {
        'target_uid': uid,
        'new_role': role.wire,
      });
    } catch (_) {
      // Fallback for offline or pre-migration builds: old read-then-write
      final oldRole = await _roleOf(uid);
      await CloudBackend.instance.upsert('users', uid, {'role': role.wire}, pk: 'uid');
      try {
        await CloudBackend.instance.addDoc('role_audit', {
          'uid': uid,
          'byUid': me.uid,
          'byEmail': me.email,
          'oldRole': oldRole,
          'newRole': role.wire,
          'at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
    if (uid == cachedUser.uid) {
      await LocalDatabase.instance.put(
        AppConstants.boxProfile,
        'me',
        cachedUser.copyWith(role: role).toJson(),
      );
    }
    logActivity(ActivityType.roleChanged, 'Changed role to ${role.label}', meta: {'targetUid': uid});
  }

  /// Reads a user's current role from the cloud (best-effort; defaults to
  /// the previous local knowledge when offline).
  static Future<String> _roleOf(String uid) async {
    try {
      final doc = await CloudBackend.instance.fetchDoc('users', uid, pk: 'uid');
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
  Future<void> revokeUser(
    String uid, {
    String? email,
    String? displayName,
  }) async {
    final me = cachedUser;
    final oldRole = await _roleOf(uid);
    try {
      await CloudBackend.instance.rpc('revoke_user_atomic', {
        'target_uid': uid,
        'target_email': email ?? '',
        'target_name': displayName ?? '',
        'old_role': oldRole,
      });
    } catch (_) {
      await CloudBackend.instance.upsert('revoked', uid, {
        'uid': uid,
        'email': email ?? '',
        'displayName': displayName ?? '',
        'role': oldRole,
        'revokedAt': DateTime.now().toIso8601String(),
        'byUid': me.uid,
        'byEmail': me.email,
      }, pk: 'uid');
      await CloudBackend.instance.remove('users', uid, pk: 'uid');
      try {
        await CloudBackend.instance.addDoc('role_audit', {
          'uid': uid,
          'byUid': me.uid,
          'byEmail': me.email,
          'oldRole': oldRole,
          'newRole': 'revoked',
          'at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
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
      final marker = await CloudBackend.instance.fetchDoc('revoked', uid, pk: 'uid');
      if (marker != null && marker['role'] is String) {
        oldRole = marker['role'] as String;
      }
    } catch (_) {}
    await CloudBackend.instance.remove('revoked', uid, pk: 'uid');
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

  /// Restores every revoked account at once — removes each `revoked/{uid}`
  /// marker so the rules re-allow those profiles, and logs one audit entry
  /// per restored account. Returns `(restored, failed)` so partial failures
  /// can be surfaced instead of swallowed.
  Future<({int restored, int failed})> restoreAllUsers() async {
    final me = cachedUser;
    final markers = await CloudBackend.instance
        .watchCollection('revoked', pk: 'uid')
        .first;
    var restored = 0;
    var failed = 0;
    for (final marker in markers) {
      final uid = marker['uid'] is String ? marker['uid'] as String : '';
      if (uid.isEmpty) {
        failed++;
        continue;
      }
      try {
        await CloudBackend.instance.remove('revoked', uid, pk: 'uid');
        try {
          await CloudBackend.instance.addDoc('role_audit', {
            'uid': uid,
            'byUid': me.uid,
            'byEmail': me.email,
            'oldRole': (marker['role'] as String?) ?? 'revoked',
            'newRole': 'restored',
            'at': DateTime.now().toIso8601String(),
          });
        } catch (_) {
          // Best-effort audit.
        }
        restored++;
      } catch (_) {
        // Skip markers that failed; keep restoring the rest.
        failed++;
      }
    }
    return (restored: restored, failed: failed);
  }

  /// Sets the subscription tier. Plan changes are admin-only in the rules.
  /// A rejected cloud write (permission-denied) is NOT an offline hiccup:
  /// the plan must not be granted locally, so the error propagates and the
  /// local entitlement is left untouched. Only offline/retryable failures
  /// keep the local-first fallback.
  Future<void> updatePlan(String uid, AppPlan plan) async {
    try {
      await CloudBackend.instance.upsert('users', uid, {'plan': plan.wire}, pk: 'uid');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('permission-denied') ||
          msg.contains('Missing or insufficient permissions')) {
        rethrow;
      }
      // Offline / network — keep the local entitlement so the UI still
      // reflects the upgrade and syncs when connectivity returns.
    }
    if (uid == cachedUser.uid) {
      await LocalDatabase.instance.put(
        AppConstants.boxProfile,
        'me',
        cachedUser.copyWith(plan: plan).toJson(),
      );
    }
  }

  /// Re-downloads the signed-in profile photo from Storage after a
  /// reinstall (local file gone, [AppUser.photoUrl] survived in the cloud
  /// profile). Writes only the local copy — the remote file already exists,
  /// so it must never be re-uploaded. Idempotent: skips when the local file
  /// is already on disk or there is no remote URL.
  Future<void> recoverProfilePhoto() async {
    final cloud = CloudBackend.instance;
    if (!cloud.isReady) return;
    final me = cachedUser;
    if (me.photoUrl.isEmpty) return;
    // Already have the file locally — nothing to do.
    if (me.photoPath.isNotEmpty && File(me.photoPath).existsSync()) return;
    // Try the cloud URL first (Supabase Storage or HTTP).
    var bytes = await cloud.downloadBytes(me.photoUrl);
    if (bytes == null || bytes.isEmpty) return;
    final path = await FileStorageService.instance.saveImageBytes(bytes);
    await LocalDatabase.instance.put(
      AppConstants.boxProfile,
      'me',
      me.copyWith(photoPath: path).toJson(),
    );
  }

  /// Updates the local + cloud copy of the signed-in profile.
  ///
  /// Deliberately has NO role parameter: roles are admin-managed only — the
  /// RLS policies reject any self-service role change, and the admin panel
  /// (Users screen) is the sole writer. Keeping role out of this method means
  /// the profile editor can never even *attempt* an escalation the rules
  /// would have to block.
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? photoPath,
    String? photoUrl,
  }) async {
    final me = cachedUser;
    // If a new local photoPath was provided, upload it to Supabase Storage
    // so the image survives sign-in on a second device.
    if (photoPath != null && photoPath.isNotEmpty) {
      try {
        final file = File(photoPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final url = await CloudBackend.instance.uploadBytes(
            'profile/${me.uid}/avatar.jpg',
            bytes,
            contentType: 'image/jpeg',
          );
          if (url != null) photoUrl = url;
        }
      } catch (_) {
        // Upload failed — keep local-only avatar; next sync will retry.
      }
    }
    final updated = me.copyWith(
      displayName: displayName,
      bio: bio,
      photoPath: photoPath,
      photoUrl: photoUrl ?? me.photoUrl,
    );
    await LocalDatabase.instance.put(
      AppConstants.boxProfile,
      'me',
      updated.toJson(),
    );
    await CloudBackend.instance.upsert('users', me.uid, {
      'displayName': updated.displayName,
      'bio': updated.bio,
      'photoPath': updated.photoPath,
      'photoUrl': updated.photoUrl,
      'email': AppUser.maskedEmail(updated.email),
    }, pk: 'uid');
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
  /// Verified against an HMAC-SHA256 to detect tampering by a root user.
  Future<List<double>?> get faceEmbedding async {
    final raw = await _secure.read(key: AppConstants.kFaceEmbedding);
    final hmac = await _secure.read(key: '${AppConstants.kFaceEmbedding}_hmac');
    if (raw == null || raw.isEmpty) {
      await FaceDebugLog.instance.log('faceEmbedding read: null/empty');
      return null;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      // Integrity check: reject tampered embeddings.
      if (hmac != null && hmac.isNotEmpty) {
        final computed = _hmacSha256(raw);
        if (!_constantTimeEquals(computed, hmac)) {
          return null;
        }
      }
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
    // Store HMAC so root tampering is detectable on next read.
    await _secure.write(
      key: '${AppConstants.kFaceEmbedding}_hmac',
      value: _hmacSha256(encoded),
    );
    await FaceDebugLog.instance.log('saveFaceEmbedding write completed');
  }

  Future<void> clearFaceEmbedding() async {
    await _secure.delete(key: AppConstants.kFaceEmbedding);
    await _secure.delete(key: '${AppConstants.kFaceEmbedding}_hmac');
  }

  // ---------------------------------------------------------- Face lockout --

  /// How long the face scan stays locked (zero = not throttled).
  /// Stored in Flutter Secure Storage (OS keychain) so the lockout survives
  /// app restarts — an attacker cannot brute-force by killing the app.
  Future<Duration> faceLockRemaining() async {
    final untilStr = await _secure.read(key: AppConstants.kFaceLockedUntil);
    final until = int.tryParse(untilStr ?? '') ?? 0;
    if (until <= 0) return Duration.zero;
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      until,
    ).difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Records a wrong face-scan attempt and returns the new lockout duration
  /// (zero when still under the attempt threshold). Once the threshold is
  /// crossed, each further failure doubles the wait up to a cap.
  Future<Duration> registerFaceFailure() async {
    final curStr = await _secure.read(key: AppConstants.kFaceFailures);
    final failures = (int.tryParse(curStr ?? '') ?? 0) + 1;
    await _secure.write(
      key: AppConstants.kFaceFailures,
      value: failures.toString(),
    );
    if (failures < AppConstants.kFaceMaxAttempts) return Duration.zero;
    final steps = failures - AppConstants.kFaceMaxAttempts + 1;
    var lockout = AppConstants.kFaceLockoutStart;
    for (var i = 1; i < steps; i++) {
      lockout *= 2;
      if (lockout >= AppConstants.kFaceLockoutMax) break;
    }
    if (lockout > AppConstants.kFaceLockoutMax) {
      lockout = AppConstants.kFaceLockoutMax;
    }
    await _secure.write(
      key: AppConstants.kFaceLockedUntil,
      value: DateTime.now().add(lockout).millisecondsSinceEpoch.toString(),
    );
    return lockout;
  }

  /// Clears the face failure counter and any active lockout (successful
  /// unlock or re-enrollment).
  Future<void> resetFaceAttempts() async {
    await _secure.write(key: AppConstants.kFaceFailures, value: '0');
    await _secure.write(key: AppConstants.kFaceLockedUntil, value: '0');
  }

  /// HMAC-SHA256 of [data] using a device-derived key.
  /// The key is the session UID (stable per install) so a different device
  /// can't verify this device's embeddings, and a factory reset loses it.
  String _hmacSha256(String data) {
    // Use the Hive session UID (set during _persistUser on every login
    // and in restoreSession) as the primary source.  This is set BEFORE
    // cachedUser is accessed, so it's reliable on cold starts.  Fall back
    // to cachedUser.uid only if Hive hasn't been written yet.
    final hiveUid = (LocalDatabase.instance.getSetting(AppConstants.kSessionUid) ?? '') as String;
    final uid = hiveUid.isNotEmpty ? hiveUid : cachedUser.uid;
    final key = utf8.encode(uid.isNotEmpty ? uid : 'default');
    final mac = crypto.Hmac(crypto.sha256, key);
    return mac.convert(utf8.encode(data)).toString();
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

  /// True when a passcode has been set. Only a salted PBKDF2 digest is kept
  /// in secure storage; the raw PIN never touches disk.
  Future<bool> get passcodeSet async {
    final hash = await _secure.read(key: AppConstants.kPasscodeHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Stores a new passcode as a salted PBKDF2-HMAC-SHA256 digest.
  Future<void> setPasscode(String pin) async {
    final salt = _randomSalt();
    final digest = _pbkdf2Sha256Hex(pin, _hexToBytes(salt), _pbkdf2Iterations);
    await _secure.write(
      key: AppConstants.kPasscodeHash,
      value: 'v2:$salt:$_pbkdf2Iterations:$digest',
    );
    // A freshly set passcode starts from a clean attempt counter.
    await resetPasscodeAttempts();
  }

  /// Verifies [pin] against the stored digest. Legacy v1 digests (salted
  /// SHA-256) are still accepted, but a successful legacy verify upgrades
  /// the stored hash to the v2 PBKDF2 format in place.
  Future<bool> verifyPasscode(String pin) async {
    final stored = await _secure.read(key: AppConstants.kPasscodeHash);
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length == 2) {
      // Legacy v1: salt:sha256(salt|pin).
      final ok = _constantTimeEquals(_digestPin(parts[0], pin), parts[1]);
      if (ok) {
        // Upgrade to the v2 format so the weak digest is replaced.
        try {
          await setPasscode(pin);
        } catch (_) {
          // Best-effort: a secure-storage hiccup must not fail the unlock.
        }
      }
      return ok;
    }
    if (parts.length == 4 && parts[0] == 'v2') {
      final salt = _hexToBytes(parts[1]);
      final iterations = int.tryParse(parts[2]) ?? _pbkdf2Iterations;
      final actual = _pbkdf2Sha256Hex(pin, salt, iterations);
      return _constantTimeEquals(actual, parts[3]);
    }
    return false;
  }

  /// Removes the stored passcode.
  Future<void> clearPasscode() async {
    await _secure.delete(key: AppConstants.kPasscodeHash);
    await resetPasscodeAttempts();
  }

  /// How long the passcode pad stays locked (zero = not throttled).
  /// Stored in Flutter Secure Storage (OS keychain) so the lockout survives
  /// app reinstalls — an attacker cannot brute-force by reinstalling.
  Future<Duration> passcodeLockRemaining() async {
    final untilStr = await _secure.read(key: AppConstants.kPasscodeLockedUntil);
    final until = int.tryParse(untilStr ?? '') ?? 0;
    if (until <= 0) return Duration.zero;
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      until,
    ).difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Records a wrong passcode attempt and returns the new lockout duration
  /// (zero when still under the attempt threshold). Once the threshold is
  /// crossed, each further failure doubles the wait up to a cap.
  Future<Duration> registerPasscodeFailure() async {
    final curStr = await _secure.read(key: AppConstants.kPasscodeFailures);
    final failures = (int.tryParse(curStr ?? '') ?? 0) + 1;
    await _secure.write(
      key: AppConstants.kPasscodeFailures,
      value: failures.toString(),
    );
    if (failures < AppConstants.kPasscodeMaxAttempts) return Duration.zero;
    final steps = failures - AppConstants.kPasscodeMaxAttempts + 1;
    var lockout = AppConstants.kPasscodeLockoutStart;
    for (var i = 1; i < steps; i++) {
      lockout *= 2;
      if (lockout >= AppConstants.kPasscodeLockoutMax) break;
    }
    if (lockout > AppConstants.kPasscodeLockoutMax) {
      lockout = AppConstants.kPasscodeLockoutMax;
    }
    await _secure.write(
      key: AppConstants.kPasscodeLockedUntil,
      value: DateTime.now().add(lockout).millisecondsSinceEpoch.toString(),
    );
    return lockout;
  }

  /// Clears the failure counter and any active lockout (successful unlock,
  /// passcode change, or new passcode).
  Future<void> resetPasscodeAttempts() async {
    await _secure.write(key: AppConstants.kPasscodeFailures, value: '0');
    await _secure.write(key: AppConstants.kPasscodeLockedUntil, value: '0');
  }

  static String _randomSalt() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// Legacy v1 digest (kept only to verify already-stored hashes).
  static String _digestPin(String salt, String pin) =>
      crypto.sha256.convert(utf8.encode('$salt:$pin')).toString();

  /// PBKDF2-HMAC-SHA256 (RFC 2898), one 32-byte output block. Iterations are
  /// chosen so a verify takes ~50-150ms on modern phones — fast enough for
  /// an unlock, slow enough to make offline brute-force of a 4-digit PIN
  /// impractical.
  static const int _pbkdf2Iterations = 150000;

  static String _pbkdf2Sha256Hex(
    String password,
    List<int> salt,
    int iterations,
  ) {
    final mac = crypto.Hmac(crypto.sha256, utf8.encode(password));
    final block = BytesBuilder()
      ..add(salt)
      ..addByte(0)
      ..addByte(0)
      ..addByte(0)
      ..addByte(1); // INT_32_BE(1) — single block is enough for 32 bytes.
    var u = mac.convert(block.takeBytes()).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = mac.convert(u).bytes;
      for (var j = 0; j < u.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _hexToBytes(String hex) => [
    for (var i = 0; i + 1 < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];

  /// Length-independent comparison so a timing side-channel can't leak how
  /// many leading digest characters match.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // ------------------------------------------------------------------ Misc --

  Future<void> welcomeNotification() async {
    await NotificationService.instance.notify(
      'Welcome to ArtVault',
      'Your private art gallery is ready. Add your first painting to begin.',
      type: 'system',
    );
  }
}

String _friendlyAuthMessage(Object e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('invalid-credential') || msg.contains('wrong-password')) {
    return 'Incorrect email or password.';
  }
  if (msg.contains('user-not-found')) return 'No account found for that email.';
  if (msg.contains('email-already-in-use')) {
    return 'That email is already registered.';
  }
  if (msg.contains('weak-password')) {
    return 'Password is too weak (min 6 characters).';
  }
  if (msg.contains('network-request-failed')) {
    return 'Network error. Check your connection.';
  }
  if (msg.contains('too-many-requests')) {
    return 'Too many attempts. Try again later.';
  }
  if (msg.contains('invalid-email')) return 'That email address is invalid.';
  if (msg.contains('user-disabled')) return 'This account has been disabled.';
  // Strip "Exception: " prefix for cleaner UI.
  return e
      .toString()
      .replaceAll('Exception: ', '')
      .replaceAll('FirebaseAuthException', '')
      .trim();
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
