/// Documents attached to a painting (certificates, invoices, provenance…).
class ArtDocument {
  final String id;
  final String paintingId;
  final String type; // one of AppConstants.documentTypes
  final String name;
  final String localPath;
  final String remoteUrl;
  final String mimeType;
  final int sizeBytes;
  final bool isDeleted;
  final bool needsSync;
  final bool synced;
  final String ownerUid;
  final DateTime createdAt;

  const ArtDocument({
    required this.id,
    required this.paintingId,
    required this.type,
    required this.name,
    this.localPath = '',
    this.remoteUrl = '',
    this.mimeType = 'application/pdf',
    this.sizeBytes = 0,
    this.isDeleted = false,
    this.needsSync = true,
    this.synced = false,
    this.ownerUid = '',
    required this.createdAt,
  });

  ArtDocument copyWith({
    String? paintingId,
    String? type,
    String? name,
    String? localPath,
    String? remoteUrl,
    String? mimeType,
    int? sizeBytes,
    bool? isDeleted,
    bool? needsSync,
    bool? synced,
    String? ownerUid,
  }) {
    return ArtDocument(
      id: id,
      paintingId: paintingId ?? this.paintingId,
      type: type ?? this.type,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
      synced: synced ?? this.synced,
      ownerUid: ownerUid ?? this.ownerUid,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'paintingId': paintingId,
    'type': type,
    'name': name,
    'localPath': localPath,
    'remoteUrl': remoteUrl,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'isDeleted': isDeleted,
    'needsSync': needsSync,
    'synced': synced,
    'ownerUid': ownerUid,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ArtDocument.fromJson(Map<String, dynamic> json) => ArtDocument(
    id: json['id'] as String,
    paintingId: (json['paintingId'] as String?) ?? '',
    type: (json['type'] as String?) ?? 'Other',
    name: (json['name'] as String?) ?? 'Untitled',
    localPath: (json['localPath'] as String?) ?? '',
    remoteUrl: (json['remoteUrl'] as String?) ?? '',
    mimeType: (json['mimeType'] as String?) ?? 'application/octet-stream',
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    isDeleted: (json['isDeleted'] as bool?) ?? false,
    needsSync: (json['needsSync'] as bool?) ?? true,
    synced: (json['synced'] as bool?) ?? false,
    ownerUid: (json['ownerUid'] as String?) ?? '',
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now(),
  );
}
