/// An artist/profile associated with one or many paintings.
class Artist {
  final String id;
  final String name;
  final String photoPath;
  final String photoUrl;
  final String biography;
  final String nationality;
  final String phone;
  final String email;
  final String website;
  final String instagram;
  final String facebook;
  final List<String> awards;
  final List<String> exhibitions;
  final bool isDeleted;
  final bool needsSync;
  final bool synced;
  final String ownerUid;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Artist({
    required this.id,
    required this.name,
    this.photoPath = '',
    this.photoUrl = '',
    this.biography = '',
    this.nationality = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.instagram = '',
    this.facebook = '',
    this.awards = const [],
    this.exhibitions = const [],
    this.isDeleted = false,
    this.needsSync = true,
    this.synced = false,
    this.ownerUid = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Artist copyWith({
    String? name,
    String? photoPath,
    String? photoUrl,
    String? biography,
    String? nationality,
    String? phone,
    String? email,
    String? website,
    String? instagram,
    String? facebook,
    List<String>? awards,
    List<String>? exhibitions,
    bool? isDeleted,
    bool? needsSync,
    bool? synced,
    String? ownerUid,
  }) {
    return Artist(
      id: id,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      biography: biography ?? this.biography,
      nationality: nationality ?? this.nationality,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      awards: awards ?? this.awards,
      exhibitions: exhibitions ?? this.exhibitions,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
      synced: synced ?? this.synced,
      ownerUid: ownerUid ?? this.ownerUid,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'photoPath': photoPath,
        'photoUrl': photoUrl,
        'biography': biography,
        'nationality': nationality,
        'phone': phone,
        'email': email,
        'website': website,
        'instagram': instagram,
        'facebook': facebook,
        'awards': awards,
        'exhibitions': exhibitions,
        'isDeleted': isDeleted,
        'needsSync': needsSync,
        'synced': synced,
        'ownerUid': ownerUid,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Unknown',
        photoPath: (json['photoPath'] as String?) ?? '',
        photoUrl: (json['photoUrl'] as String?) ?? '',
        biography: (json['biography'] as String?) ?? '',
        nationality: (json['nationality'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        website: (json['website'] as String?) ?? '',
        instagram: (json['instagram'] as String?) ?? '',
        facebook: (json['facebook'] as String?) ?? '',
        awards: (json['awards'] as List?)?.whereType<String>().toList() ?? const [],
        exhibitions: (json['exhibitions'] as List?)?.whereType<String>().toList() ?? const [],
        isDeleted: (json['isDeleted'] as bool?) ?? false,
        needsSync: (json['needsSync'] as bool?) ?? true,
        synced: (json['synced'] as bool?) ?? false,
        ownerUid: (json['ownerUid'] as String?) ?? '',
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}
