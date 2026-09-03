import 'dart:ui' show Color;

import '../../core/utils/image_utils.dart';

/// A single artwork in the vault. Immutable, serialisable to/from JSON for
/// both local (Hive) persistence and remote (Cloud Firestore) sync.
class Painting {
  final String id;
  final String title;
  final String artistId;
  final String artistName;

  final String category;
  final String medium;
  final String style;

  final String description;
  final List<String> tags;

  // Dimensions
  final double? width;
  final double? height;
  final double? depth;
  final String dimensionUnit;
  final double? weight;
  final String weightUnit;

  // Commercial
  final double? price;
  final String currency;
  final String availability;
  final String location;
  final double? lat;
  final double? lng;
  final List<Map<String, dynamic>> provenance;
  final List<Map<String, dynamic>> priceHistory;

  // Media
  final String coverImagePath; // local file path
  final String coverImageUrl; // remote (Firebase Storage) URL
  final List<String> images; // all local paths
  final List<String> imageUrls; // all remote urls
  final List<String>
  driveFileIds; // Google Drive file IDs (parallel to imageUrls)

  // AI
  final String aiHash; // perceptual hash for duplicate detection
  final List<String> aiTags;
  final List<String> dominantColors;
  final double brightness;
  final double contrast;
  final String orientation;
  final double complexity;
  final String styleConfidence;

  final bool isFavorite;
  final bool inPublicGallery;
  final bool isDeleted;
  final bool needsSync;
  final bool synced;
  final String ownerUid;

  final String? dateCreated; // artist-made date (display string)
  final DateTime createdAt;
  final DateTime updatedAt;

  const Painting({
    required this.id,
    required this.title,
    required this.artistId,
    required this.artistName,
    this.category = '',
    this.medium = '',
    this.style = '',
    this.description = '',
    this.tags = const [],
    this.width,
    this.height,
    this.depth,
    this.dimensionUnit = 'cm',
    this.weight,
    this.weightUnit = 'kg',
    this.price,
    this.currency = 'USD',
    this.availability = 'Available',
    this.location = '',
    this.lat,
    this.lng,
    this.provenance = const [],
    this.priceHistory = const [],
    this.coverImagePath = '',
    this.coverImageUrl = '',
    this.images = const [],
    this.imageUrls = const [],
    this.driveFileIds = const [],
    this.aiHash = '',
    this.aiTags = const [],
    this.dominantColors = const [],
    this.brightness = 0.5,
    this.contrast = 0.5,
    this.orientation = 'Landscape',
    this.complexity = 0.5,
    this.styleConfidence = 'Medium',
    this.isFavorite = false,
    this.inPublicGallery = false,
    this.isDeleted = false,
    this.needsSync = true,
    this.synced = false,
    this.ownerUid = '',
    this.dateCreated,
    required this.createdAt,
    required this.updatedAt,
  });

  Painting copyWith({
    String? title,
    String? artistId,
    String? artistName,
    String? category,
    String? medium,
    String? style,
    String? description,
    List<String>? tags,
    double? width,
    double? height,
    double? depth,
    String? dimensionUnit,
    double? weight,
    String? weightUnit,
    double? price,
    String? currency,
    String? availability,
    String? location,
    double? lat,
    double? lng,
    List<Map<String, dynamic>>? provenance,
    List<Map<String, dynamic>>? priceHistory,
    String? coverImagePath,
    String? coverImageUrl,
    List<String>? images,
    List<String>? imageUrls,
    List<String>? driveFileIds,
    String? aiHash,
    List<String>? aiTags,
    List<String>? dominantColors,
    double? brightness,
    double? contrast,
    String? orientation,
    double? complexity,
    String? styleConfidence,
    bool? isFavorite,
    bool? inPublicGallery,
    bool? isDeleted,
    bool? needsSync,
    bool? synced,
    String? ownerUid,
    String? dateCreated,
    DateTime? updatedAt,
  }) {
    return Painting(
      id: id,
      title: title ?? this.title,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      category: category ?? this.category,
      medium: medium ?? this.medium,
      style: style ?? this.style,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      width: width ?? this.width,
      height: height ?? this.height,
      depth: depth ?? this.depth,
      dimensionUnit: dimensionUnit ?? this.dimensionUnit,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      availability: availability ?? this.availability,
      location: location ?? this.location,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      provenance: provenance ?? this.provenance,
      priceHistory: priceHistory ?? this.priceHistory,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      images: images ?? this.images,
      imageUrls: imageUrls ?? this.imageUrls,
      driveFileIds: driveFileIds ?? this.driveFileIds,
      aiHash: aiHash ?? this.aiHash,
      aiTags: aiTags ?? this.aiTags,
      dominantColors: dominantColors ?? this.dominantColors,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      orientation: orientation ?? this.orientation,
      complexity: complexity ?? this.complexity,
      styleConfidence: styleConfidence ?? this.styleConfidence,
      isFavorite: isFavorite ?? this.isFavorite,
      inPublicGallery: inPublicGallery ?? this.inPublicGallery,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
      synced: synced ?? this.synced,
      ownerUid: ownerUid ?? this.ownerUid,
      dateCreated: dateCreated ?? this.dateCreated,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Marks the record as fully mirrored to the cloud.
  ///
  /// Deliberately does NOT touch [isDeleted] — sync state is orthogonal to
  /// trash state, and clearing it here would resurrect a trashed painting
  /// on the next background sync.
  Painting markSynced() => copyWith(needsSync: false, synced: true);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artistId': artistId,
    'artistName': artistName,
    'category': category,
    'medium': medium,
    'style': style,
    'description': description,
    'tags': tags,
    'width': width,
    'height': height,
    'depth': depth,
    'dimensionUnit': dimensionUnit,
    'weight': weight,
    'weightUnit': weightUnit,
    'price': price,
    'currency': currency,
    'availability': availability,
    'location': location,
    'lat': lat,
    'lng': lng,
    'provenance': provenance,
    'priceHistory': priceHistory,
    'coverImagePath': coverImagePath,
    'coverImageUrl': coverImageUrl,
    'images': images,
    'imageUrls': imageUrls,
    'driveFileIds': driveFileIds,
    'aiHash': aiHash,
    'aiTags': aiTags,
    'dominantColors': dominantColors,
    'brightness': brightness,
    'contrast': contrast,
    'orientation': orientation,
    'complexity': complexity,
    'styleConfidence': styleConfidence,
    'isFavorite': isFavorite,
    'inPublicGallery': inPublicGallery,
    'isDeleted': isDeleted,
    'needsSync': needsSync,
    'synced': synced,
    'ownerUid': ownerUid,
    'dateCreated': dateCreated,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Painting.fromJson(Map<String, dynamic> json) => Painting(
    id: json['id'] as String,
    title: (json['title'] as String?) ?? 'Untitled',
    artistId: (json['artistId'] as String?) ?? '',
    artistName: (json['artistName'] as String?) ?? 'Unknown',
    category: (json['category'] as String?) ?? '',
    medium: (json['medium'] as String?) ?? '',
    style: (json['style'] as String?) ?? '',
    description: (json['description'] as String?) ?? '',
    tags: _list(json['tags']),
    width: _double(json['width']),
    height: _double(json['height']),
    depth: _double(json['depth']),
    dimensionUnit: (json['dimensionUnit'] as String?) ?? 'cm',
    weight: _double(json['weight']),
    weightUnit: (json['weightUnit'] as String?) ?? 'kg',
    price: _double(json['price']),
    currency: (json['currency'] as String?) ?? 'USD',
    availability: (json['availability'] as String?) ?? 'Available',
    location: (json['location'] as String?) ?? '',
    lat: _double(json['lat']),
    lng: _double(json['lng']),
    provenance: _listMap(json['provenance']),
    priceHistory: _listMap(json['priceHistory']),
    coverImagePath: (json['coverImagePath'] as String?) ?? '',
    coverImageUrl: (json['coverImageUrl'] as String?) ?? '',
    images: _list(json['images']),
    imageUrls: _list(json['imageUrls']),
    driveFileIds: _list(json['driveFileIds']),
    aiHash: (json['aiHash'] as String?) ?? '',
    aiTags: _list(json['aiTags']),
    dominantColors: _list(json['dominantColors']),
    brightness: _double(json['brightness']) ?? 0.5,
    contrast: _double(json['contrast']) ?? 0.5,
    orientation: (json['orientation'] as String?) ?? 'Landscape',
    complexity: _double(json['complexity']) ?? 0.5,
    styleConfidence: (json['styleConfidence'] as String?) ?? 'Medium',
    isFavorite: (json['isFavorite'] as bool?) ?? false,
    inPublicGallery: (json['inPublicGallery'] as bool?) ?? false,
    isDeleted: (json['isDeleted'] as bool?) ?? false,
    needsSync: (json['needsSync'] as bool?) ?? true,
    synced: (json['synced'] as bool?) ?? false,
    ownerUid: (json['ownerUid'] as String?) ?? '',
    dateCreated: json['dateCreated'] as String?,
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    updatedAt: _date(json['updatedAt']) ?? DateTime.now(),
  );

  static List<String> _list(dynamic v) {
    if (v is List) return v.whereType<String>().toList();
    return const [];
  }

  static List<Map<String, dynamic>> _listMap(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  static double? _double(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _date(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  /// Dominant color as a usable [Color].
  Color? get primaryColor => dominantColors.isEmpty
      ? null
      : ImageUtils.colorFromHex(dominantColors.first);
}
