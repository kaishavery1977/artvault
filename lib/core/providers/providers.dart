import 'dart:async';

import 'package:disk_space_2/disk_space_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_user.dart';
import '../../data/models/art_document.dart';
import '../../data/models/artist.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/artist_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/painting_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/remote/cloud_backend.dart';
import '../services/file_storage_service.dart';

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return SettingsRepository.instance.themeMode;
});

final localeProvider = StateProvider<String>((ref) {
  return SettingsRepository.instance.locale;
});

/// True when the user has finished onboarding.
final onboardedProvider = StateProvider<bool>((ref) {
  return SettingsRepository.instance.onboarded;
});

/// True once the full cinematic splash intro has played; drives the switch
/// to the shorter quick intro on subsequent launches.
final splashIntroShownProvider = StateProvider<bool>((ref) {
  return SettingsRepository.instance.splashIntroShown;
});

/// Preferred currency used across the UI.
final currencyProvider = Provider<String>((ref) {
  return SettingsRepository.instance.preferredCurrency;
});

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

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState());

  AuthRepository get _repo => AuthRepository.instance;

  /// Called at startup — restores a remembered/secure session without UI.
  Future<void> bootstrap() async {
    if (await _repo.hasRememberedSession) {
      try {
        final user = await _repo.restoreSession();
        state = AuthState(status: AuthStatus.authenticated, user: user);
        _pullVaultInBackground();
        return;
      } catch (_) {}
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Pulls the cloud vault after a successful sign-in so the home screen
  /// isn't empty until the user manually taps Sync. Fire-and-forget: the
  /// repositories are offline-first and each sync is a safe no-op when
  /// Firebase isn't configured.
  void _pullVaultInBackground() {
    unawaited(PaintingRepository.instance.syncNow());
    unawaited(ArtistRepository.instance.syncNow());
    unawaited(DocumentRepository.instance.syncNow());
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
      state = AuthState(status: AuthStatus.authenticated, user: user);
      _pullVaultInBackground();
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await _repo.register(name, email, password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      _pullVaultInBackground();
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
      state = AuthState(status: AuthStatus.authenticated, user: user);
      _pullVaultInBackground();
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
      state = AuthState(status: AuthStatus.authenticated, user: user);
      _pullVaultInBackground();
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
    await _repo.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> updateRole(AppRole role) async {
    final user = state.user;
    if (user == null) return;
    await _repo.updateRole(user.uid, role);
    state = state.copyWith(user: user.copyWith(role: role));
  }

  /// Reloads the signed-in profile from local storage so edits (avatar,
  /// display name, bio, role) appear immediately in the UI.
  Future<void> refreshProfile() async {
    final user = _repo.cachedUser;
    if (user.uid.isEmpty) return;
    state = state.copyWith(user: user);
  }

  static String _message(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg.contains('firebase_auth')) {
      return 'Sign-in failed. Check your credentials.';
    }
    return msg.isEmpty ? 'Something went wrong. Please try again.' : msg;
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});

// ---------------------------------------------------------------------------
// Collection data
// ---------------------------------------------------------------------------

final paintingsProvider = StreamProvider<List<Painting>>((ref) {
  return PaintingRepository.instance.watchPaintings();
});

final artistsProvider = StreamProvider<List<Artist>>((ref) {
  return ArtistRepository.instance.watchArtists();
});

final documentsProvider = StreamProvider<List<ArtDocument>>((ref) {
  return DocumentRepository.instance.watchDocuments();
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  return NotificationRepository.instance.watch();
});

/// Registered user profiles (RBAC admin view).
///
/// Streams the Firestore `users` collection when Firebase is connected;
/// falls back to the signed-in profile when offline so the admin screen
/// remains usable on a device-only vault.
final usersProvider = StreamProvider<List<AppUser>>((ref) async* {
  final cloud = CloudBackend.instance;
  if (cloud.isReady) {
    yield* cloud.watchUsers().map(
      (list) => list.map(AppUser.fromJson).toList()
        ..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        ),
    );
  } else {
    yield [AuthRepository.instance.cachedUser];
  }
});

/// On-disk storage usage (bytes) broken down by category.
class StorageUsage {
  final int images;
  final int documents;
  final int exports;

  const StorageUsage({this.images = 0, this.documents = 0, this.exports = 0});

  int get total => images + documents + exports;
}

final storageUsageProvider = FutureProvider<StorageUsage>((ref) async {
  final breakdown = await FileStorageService.instance.storageBreakdown();
  return StorageUsage(
    images: breakdown.images,
    documents: breakdown.documents,
    exports: breakdown.exports,
  );
});

/// Phone-wide disk space in bytes (null when the platform doesn't expose it).
class DeviceStorage {
  final int freeBytes;
  final int totalBytes;

  const DeviceStorage({required this.freeBytes, required this.totalBytes});

  int get usedBytes => totalBytes - freeBytes;

  /// Fraction (0..1) of the phone's storage currently in use.
  double get usedFraction => totalBytes > 0 ? usedBytes / totalBytes : 0;
}

/// Reads the phone's total and free disk space so the UI can show how much
/// storage remains on the device, not just what the vault itself uses.
///
/// `disk_space_2` returns values in mebibytes (2^20 bytes) on Android and
/// iOS, so convert to bytes with 1024*1024 — not 1024^3.
final deviceStorageProvider = FutureProvider<DeviceStorage?>((ref) async {
  try {
    final freeMiB = await DiskSpace.getFreeDiskSpace;
    final totalMiB = await DiskSpace.getTotalDiskSpace;
    if (freeMiB == null || totalMiB == null) return null;
    const mib = 1024 * 1024;
    return DeviceStorage(
      freeBytes: (freeMiB * mib).round(),
      totalBytes: (totalMiB * mib).round(),
    );
  } catch (_) {
    return null; // graceful fallback: card shows vault-only usage as before
  }
});

/// Single painting looked up by id.
final paintingByIdProvider = Provider.family<Painting?, String>((ref, id) {
  final paintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
  for (final painting in paintings) {
    if (painting.id == id && !painting.isDeleted) return painting;
  }
  return PaintingRepository.instance.get(id);
});

/// Documents attached to one painting.
final documentsForPaintingProvider = Provider.family<List<ArtDocument>, String>(
  (ref, id) {
    final docs = ref.watch(documentsProvider).valueOrNull ?? const [];
    return docs.where((d) => d.paintingId == id && !d.isDeleted).toList();
  },
);

/// Live computed stats for the dashboard.
class VaultStats {
  final int paintings;
  final int artists;
  final int documents;
  final double collectionValue;
  final double storageBytes;
  final int favorites;

  const VaultStats({
    required this.paintings,
    required this.artists,
    required this.documents,
    required this.collectionValue,
    required this.storageBytes,
    required this.favorites,
  });
}

final vaultStatsProvider = Provider<VaultStats>((ref) {
  final paintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
  final artists = ref.watch(artistsProvider).valueOrNull ?? const [];
  final documents = ref.watch(documentsProvider).valueOrNull ?? const [];

  final active = paintings.where((p) => !p.isDeleted).toList();
  final value = active.fold<double>(0, (sum, p) => sum + (p.price ?? 0));
  return VaultStats(
    paintings: active.length,
    artists: artists.where((a) => !a.isDeleted).length,
    documents: documents.where((d) => !d.isDeleted).length,
    collectionValue: value,
    storageBytes: (ref.watch(storageUsageProvider).valueOrNull?.total ?? 0)
        .toDouble(),
    favorites: active.where((p) => p.isFavorite).length,
  );
});

/// Whether the app has cloud connectivity (Firebase configured).
/// Populated during startup bootstrap.
final cloudReadyProvider = StateProvider<bool>((ref) => false);
