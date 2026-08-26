/// Role-Based Access Control (RBAC).
///
/// Three roles power the ArtVault permissions model:
///  - [AppRole.admin]    : full access — users, analytics, backups, settings.
///  - [AppRole.curator]  : can upload / edit / organise / manage artworks.
///  - [AppRole.viewer]   : read-only access for galleries, clients, collectors.
enum AppRole { admin, curator, viewer }

extension AppRoleX on AppRole {
  String get label => switch (this) {
        AppRole.admin => 'Admin',
        AppRole.curator => 'Curator',
        AppRole.viewer => 'Viewer',
      };

  String get wire => name;

  static AppRole fromWire(String? value) => AppRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => AppRole.viewer,
      );

  bool get canEdit => this != AppRole.viewer;

  bool get canManageUsers => this == AppRole.admin;

  bool get canManageBackups => this == AppRole.admin;

  bool get canSeeAnalytics => this != AppRole.viewer;

  /// Human-readable description used in the UI.
  String get description => switch (this) {
        AppRole.admin =>
          'Full access to artworks, users, analytics, backups and settings.',
        AppRole.curator =>
          'Upload, edit, organise and manage artworks and artists.',
        AppRole.viewer =>
          'Read-only access to browse the collection. No edits allowed.',
      };
}

/// The user's subscription tier. `free` is the default; `pro` unlocks
/// premium features (unlimited capacity, gallery analytics & watermarking).
enum AppPlan { free, pro }

extension AppPlanX on AppPlan {
  String get label => switch (this) {
        AppPlan.free => 'Free',
        AppPlan.pro => 'Pro',
      };

  String get wire => name;

  bool get isPro => this == AppPlan.pro;

  static AppPlan fromWire(String? value) => AppPlan.values.firstWhere(
        (p) => p.name == value,
        orElse: () => AppPlan.free,
      );
}

/// A user profile stored locally + in Firestore (`users/{uid}`).
///
/// The real email lives only in the local Hive profile and Firebase Auth.
/// The Firestore document stores a privacy-masked version so other signed-in
/// users cannot enumerate email addresses.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String photoPath; // local avatar file (offline-first)
  final String photoUrl; // remote avatar URL
  final String bio;
  final AppRole role;
  final AppPlan plan;
  final DateTime createdAt;
  final DateTime lastLogin;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoPath = '',
    this.photoUrl = '',
    this.bio = '',
    this.role = AppRole.viewer,
    this.plan = AppPlan.free,
    required this.createdAt,
    required this.lastLogin,
  });

  AppUser copyWith({
    String? email,
    String? displayName,
    String? photoPath,
    String? photoUrl,
    String? bio,
    AppRole? role,
    AppPlan? plan,
    DateTime? lastLogin,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      plan: plan ?? this.plan,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  /// Privacy-masked email safe to store in Firestore (e.g. "k***@gmail.com").
  /// Returns the raw email when it is already too short to mask.
  static String maskedEmail(String email) {
    if (email.length < 3) return email;
    final at = email.indexOf('@');
    if (at < 1) return '${email[0]}***';
    final local = email.substring(0, at);
    final domain = email.substring(at);
    if (local.length <= 1) return '${local[0]}***$domain';
    return '${local[0]}***$domain';
  }

  /// Serialise for local Hive storage — preserves the real email.
  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoPath': photoPath,
        'photoUrl': photoUrl,
        'bio': bio,
        'role': role.wire,
        'plan': plan.wire,
        'createdAt': createdAt.toIso8601String(),
        'lastLogin': lastLogin.toIso8601String(),
      };

  /// Serialise for Firestore upload — stores masked email to protect PII.
  Map<String, dynamic> toFirestoreJson() => {
        ...toJson(),
        'email': maskedEmail(email),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: (json['uid'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        displayName: (json['displayName'] as String?) ?? 'ArtVault User',
        photoPath: (json['photoPath'] as String?) ?? '',
        photoUrl: (json['photoUrl'] as String?) ?? '',
        bio: (json['bio'] as String?) ?? '',
        role: AppRoleX.fromWire(json['role'] as String?),
        plan: AppPlanX.fromWire(json['plan'] as String?),
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        lastLogin: DateTime.tryParse((json['lastLogin'] as String?) ?? '') ??
            DateTime.now(),
      );

  static AppUser placeholder() =>
      AppUser(uid: '', email: '', displayName: 'Guest', createdAt: DateTime(0),
          lastLogin: DateTime(0));
}
