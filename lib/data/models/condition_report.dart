/// A condition report attached to a painting: physical state at a point in
/// time, an optional photo, and free-form notes. The newest report for a
/// painting drives the "last inspected" reminder on the detail screen.
class ConditionReport {
  final String id;
  final String paintingId;

  /// One of [ConditionReport.levels] (Excellent / Good / Fair / Poor / Damaged).
  final String condition;

  final String notes;
  final String photoPath; // local file
  final String photoUrl; // remote (after sync)

  final DateTime inspectedAt; // when the piece was examined
  final DateTime createdAt;
  final String ownerUid;
  final bool isDeleted;
  final bool needsSync;
  final bool synced;

  static const List<String> levels = [
    'Excellent',
    'Good',
    'Fair',
    'Poor',
    'Damaged',
  ];

  const ConditionReport({
    required this.id,
    required this.paintingId,
    this.condition = 'Good',
    this.notes = '',
    this.photoPath = '',
    this.photoUrl = '',
    required this.inspectedAt,
    required this.createdAt,
    this.ownerUid = '',
    this.isDeleted = false,
    this.needsSync = true,
    this.synced = false,
  });

  ConditionReport copyWith({
    String? paintingId,
    String? condition,
    String? notes,
    String? photoPath,
    String? photoUrl,
    DateTime? inspectedAt,
    String? ownerUid,
    bool? isDeleted,
    bool? needsSync,
    bool? synced,
  }) {
    return ConditionReport(
      id: id,
      paintingId: paintingId ?? this.paintingId,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      inspectedAt: inspectedAt ?? this.inspectedAt,
      createdAt: createdAt,
      ownerUid: ownerUid ?? this.ownerUid,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'paintingId': paintingId,
        'condition': condition,
        'notes': notes,
        'photoPath': photoPath,
        'photoUrl': photoUrl,
        'inspectedAt': inspectedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'ownerUid': ownerUid,
        'isDeleted': isDeleted,
        'needsSync': needsSync,
        'synced': synced,
      };

  factory ConditionReport.fromJson(Map<String, dynamic> json) =>
      ConditionReport(
        id: json['id'] as String,
        paintingId: (json['paintingId'] as String?) ?? '',
        condition: (json['condition'] as String?) ?? 'Good',
        notes: (json['notes'] as String?) ?? '',
        photoPath: (json['photoPath'] as String?) ?? '',
        photoUrl: (json['photoUrl'] as String?) ?? '',
        inspectedAt:
            DateTime.tryParse((json['inspectedAt'] as String?) ?? '') ??
                DateTime.now(),
        createdAt:
            DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
                DateTime.now(),
        ownerUid: (json['ownerUid'] as String?) ?? '',
        isDeleted: (json['isDeleted'] as bool?) ?? false,
        needsSync: (json['needsSync'] as bool?) ?? true,
        synced: (json['synced'] as bool?) ?? false,
      );
}
