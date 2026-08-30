import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/artist_repository.dart';
import '../../data/repositories/condition_report_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/painting_repository.dart';
import '../../data/remote/cloud_backend.dart';
import '../services/backup_service.dart';
import 'data_providers.dart';

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final bool busy;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.busy = false,
    this.error,
  });

  bool get canEdit => user?.role.canEdit ?? false;
  bool get canManageUsers => user?.role.canManageUsers ?? false;
  bool get canManageBackups => user?.role.canManageBackups ?? false;
  bool get canSeeAnalytics => user?.role.canSeeAnalytics ?? false;

  /// True when the signed-in user has the Pro subscription tier.
  bool get isPro => user?.plan.isPro ?? false;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Live progress of the vault restore-from-cloud pipeline (runs after
/// sign-in and on demand from Settings). null = idle.
class RestoreProgress {
  final bool running;
  final String stage;
  final int itemsRestored;

  const RestoreProgress({
    this.running = false,
    this.stage = '',
    this.itemsRestored = 0,
  });
}

/// Emits restore progress while the vault re-downloads from the cloud;
/// null when idle — autoDispose so the banner state doesn't linger after the
/// screen is gone and memory is freed.
final restoreProgressProvider =
    StateProvider.autoDispose<RestoreProgress?>((ref) => null);

class AuthController extends StateNotifier<AuthState> {
  AuthController({this.onRestoreProgress}) : super(const AuthState());

  /// Reports restore-from-cloud progress to the UI (wired to
  /// [restoreProgressProvider] by the provider factory).
  final void Function(RestoreProgress?)? onRestoreProgress;

  /// Guards against overlapping restore runs (sign-in kick + manual button).
  bool _restoring = false;

  AuthRepository get _repo => AuthRepository.instance;

  StreamSubscription<Map<String, dynamic>?>? _profileSub;

  /// Serialises profile-snapshot handling: Firestore can deliver overlapping
  /// snapshots, and an async callback could otherwise apply a stale update
  /// after a newer one. Only the latest snapshot runs; a snapshot that
  /// arrives while the previous is still processing is dropped.
  bool _profileApplying = false;
  Map<String, dynamic>? _profilePending;

  /// Pulls the cloud vault into the local cache after a session is restored
  /// or a fresh sign-in succeeds — a new install or a cleared cache
  /// repopulates on its own instead of showing an empty vault until a manual
  /// sync. Fire-and-forget: never blocks the splash hand-off or the UI, and
  /// no-ops when Firebase isn't ready yet.
  void _syncVaultAfterAuth() {
    unawaited(restoreFromCloud());
  }

  /// Re-downloads the vault from the cloud, either automatically after a
  /// session is restored / sign-in succeeds, or on demand from Settings.
  ///
  /// Pulls remote metadata, then re-downloads the media files (painting
  /// images, artist photos, documents, condition photos, profile photo)
  /// that a reinstall wiped locally — the remote URLs survive in
  /// Firestore, the local files do not. The pulls rebuild the local boxes
  /// first (a wiped vault has no rows, so the recover* pass alone would
  /// find nothing), then each recover* re-downloads the files. Everything
  /// is idempotent (skips files already on disk) and runs in the
  /// background.
  ///
  /// Reports live progress through [restoreProgressProvider] — the home
  /// banner and the Settings tile react without polling. Returns the total
  /// number of files re-downloaded.
  Future<int> restoreFromCloud() async {
    if (_restoring) return 0;
    _restoring = true;
    var restored = 0;

    void stage(String label) {
      onRestoreProgress?.call(
        RestoreProgress(running: true, stage: label, itemsRestored: restored),
      );
    }

    try {
      // Each stage is wrapped in its own try-catch so a failure in one
      // collection never blocks the rest — the user still gets partial
      // restore instead of nothing.
      try {
        stage('Restoring paintings…');
        await PaintingRepository.instance.syncNow();
        restored += await PaintingRepository.instance.recoverImages();
        // If syncNow pulled nothing from individual Firestore docs,
        // try the cloud backup snapshot (full vault JSON in backups/{uid}).
        if (restored == 0) {
          await BackupService.instance.restoreCloudBackup();
          restored += await PaintingRepository.instance.recoverImages();
        }
      } catch (_) {}

      try {
        stage('Restoring artists…');
        await ArtistRepository.instance.pullRemote();
        restored += await ArtistRepository.instance.recoverPhotos();
      } catch (_) {}

      try {
        stage('Restoring documents…');
        await DocumentRepository.instance.pullRemote();
        restored += await DocumentRepository.instance.recoverDocuments();
      } catch (_) {}

      try {
        stage('Restoring condition reports…');
        await ConditionReportRepository.instance.pullRemote();
        restored += await ConditionReportRepository.instance.recoverPhotos();
      } catch (_) {}

      // Profile photo: retry up to 3 times (network flakiness on cold start).
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          stage('Restoring profile photo…');
          await AuthRepository.instance.recoverProfilePhoto();
          break;
        } catch (_) {
          if (attempt < 2) {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        }
      }
      // The avatar may have swapped from a network URL to a fresh local
      // file; pick it up so the UI shows it without a restart.
      await refreshProfile();
      return restored;
    } finally {
      _restoring = false;
      // 'done' signals the completion state to the UI (banner switches to
      // a summary until dismissed; the Settings tile falls back to idle).
      onRestoreProgress?.call(
        RestoreProgress(running: false, stage: 'done', itemsRestored: restored),
      );
    }
  }

  /// Watches this account's `users/{uid}` doc so role/plan changes made by
  /// an admin (or any remote profile edit) apply on this device immediately
  /// — the RBAC guards and the whole UI react without a sign-out/sign-in
  /// cycle or an app restart.
  void _watchMyProfile(AppUser user) {
    _profileSub?.cancel();
    _profileSub = null;
    if (user.uid.isEmpty) return;
    try {
      _profileSub = CloudBackend.instance
          .watchDoc('users', user.uid, pk: 'uid')
          .listen(
            _applyProfileSnapshot,
            onError: (e, _) {
              debugPrint('watchMyProfile onError: $e');
            },
          );
    } catch (e) {
      debugPrint('watchMyProfile failed: $e');
      _profileSub = null;
    }
  }

  /// Applies one profile snapshot, serialised so overlapping snapshots can
  /// never apply out of order (a stale one is dropped, not applied late).
  Future<void> _applyProfileSnapshot(Map<String, dynamic>? data) async {
    // Profile deleted = the account was revoked by an admin. Sign the
    // session out on this device right away (remote sign-out).
    if (data == null) {
      await signOut();
      state = state.copyWith(
        error: 'Your account was revoked by an administrator.',
      );
      return;
    }
    var remote = AppUser.fromJson(data);
    if (remote.uid.isEmpty) return;
    // Older cloud profiles may lack newer fields (e.g. plan). Preserve
    // the local value for absent keys so a bare doc can't reset a
    // locally-granted Pro plan or a local avatar path.
    final local = state.user;
    if (local != null) {
      if (data['plan'] == null) {
        remote = remote.copyWith(plan: local.plan);
      }
      if (data['photoPath'] == null && local.photoPath.isNotEmpty) {
        remote = remote.copyWith(photoPath: local.photoPath);
      }
    }
    if (_profileApplying) {
      _profilePending = data;
      return;
    }
    _profileApplying = true;
    try {
      await _repo.cacheRemoteUser(remote);
      // The notifier is alive for as long as the provider is watched; the
      // stream itself is cancelled in dispose()/signOut(), so setting state
      // here is safe.
      state = state.copyWith(user: remote);
    } finally {
      _profileApplying = false;
      final pending = _profilePending;
      _profilePending = null;
      if (pending != null) {
        await _applyProfileSnapshot(pending);
      }
    }
  }

  /// Central auth-success path: set the authenticated state, kick the vault
  /// sync and start watching the profile for remote role/plan changes.
  void _onAuthenticated(AppUser user) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
    _syncVaultAfterAuth();
    _watchMyProfile(user);
    logActivity(ActivityType.signIn, '${user.displayName} signed in');
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _profileSub = null;
    _profileApplying = false;
    _profilePending = null;
    _restoring = false;
    super.dispose();
  }

  /// Called at startup — restores a remembered/secure session without UI.
  Future<void> bootstrap() async {
    if (await _repo.hasRememberedSession) {
      try {
        final user = await _repo.restoreSession();
        _onAuthenticated(user);
        return;
      } catch (_) {}
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> signInWithEmail(
    String email,
    String password, {
    bool remember = false,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await _repo.signInWithEmail(
        email,
        password,
        remember: remember,
      );
      _onAuthenticated(user);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password, {
    String? adminCode,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await _repo.register(
        name,
        email,
        password,
        adminCode: adminCode,
      );
      _onAuthenticated(user);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await _repo.signInWithGoogle();
      _onAuthenticated(user);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await _repo.signInWithApple();
      _onAuthenticated(user);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repo.sendPasswordReset(email);
      state = state.copyWith(busy: false);
      return true;
    } catch (e) {
      // Keep the real reason (unknown account, wrong address, network…) —
      // "Sign-in failed" would be misleading for a reset request.
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        busy: false,
        error: msg.isEmpty
            ? 'Could not send the reset email. Check the address and try again.'
            : msg,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    logActivity(ActivityType.signOut, 'Signed out');
    _profileSub?.cancel();
    _profileSub = null;
    _profileApplying = false;
    _profilePending = null;
    // A restore must never leak into the next session.
    onRestoreProgress?.call(null);
    await _repo.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// NOTE: there is deliberately NO `updateRole` here. Roles are changed
  /// exclusively by an admin from the Users screen (which calls
  /// AuthRepository.updateRole for the *target* account); a user must never
  /// be able to change their own role from app code — the Firestore rules
  /// enforce the same rule server-side.

  Future<void> updatePlan(AppPlan plan) async {
    final user = state.user;
    if (user == null) return;
    await _repo.updatePlan(user.uid, plan);
    state = state.copyWith(user: user.copyWith(plan: plan));
    await refreshProfile();
  }

  /// Applies a plan grant that was verified and written **server-side**
  /// (Cloud Function with the Admin SDK). The client must not rewrite the
  /// plan here — the Firestore rules reject a non-admin self plan-change, so
  /// a legitimate buyer would otherwise be blocked right after paying. We
  /// only update the local cache + state; the live profile watcher
  /// reconciles with the server document.
  Future<void> applyServerPlanGrant(AppPlan plan) async {
    final user = state.user;
    if (user == null) return;
    await _repo.cacheRemoteUser(user.copyWith(plan: plan));
    state = state.copyWith(user: user.copyWith(plan: plan));
  }

  /// Reloads the signed-in profile from local storage so edits (avatar,
  /// display name, bio, role) appear immediately in the UI.
  Future<void> refreshProfile() async {
    final user = _repo.cachedUser;
    if (user.uid.isEmpty) return;
    state = state.copyWith(user: user);
  }

  static String _message(Object e) {
    // AuthRepository already maps Firebase codes to friendly text (e.g.
    // "Incorrect email or password", "No account found"), so pass it through.
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return 'Something went wrong. Please try again.';
    return raw;
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    onRestoreProgress: (progress) =>
        ref.read(restoreProgressProvider.notifier).state = progress,
  );
});
