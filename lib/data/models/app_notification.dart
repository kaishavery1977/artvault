/// In-app notification item shown on the notifications screen.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // backup | upload | duplicate | sync | document | system
  final bool read;
  final String? paintingId;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    this.paintingId,
    required this.createdAt,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        read: read ?? this.read,
        paintingId: paintingId,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'read': read,
        'paintingId': paintingId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        type: (json['type'] as String?) ?? 'system',
        read: (json['read'] as bool?) ?? false,
        paintingId: json['paintingId'] as String?,
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}
