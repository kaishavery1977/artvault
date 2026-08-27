import '../../core/constants/app_constants.dart';
import '../local/local_database.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  NotificationRepository._();

  static final NotificationRepository instance = NotificationRepository._();

  LocalDatabase get _db => LocalDatabase.instance;

  Stream<List<AppNotification>> watch() async* {
    yield all();
    yield* _db.watch(AppConstants.boxNotifications).map((_) => all());
  }

  List<AppNotification> all() {
    final raw = _db.getAll(AppConstants.boxNotifications);
    final list = raw.map(AppNotification.fromJson).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> add(AppNotification notification) => _db.put(
    AppConstants.boxNotifications,
    notification.id,
    notification.toJson(),
  );

  Future<void> markRead(String id) async {
    final raw = _db.getById(AppConstants.boxNotifications, id);
    if (raw == null) return;
    await _db.put(
      AppConstants.boxNotifications,
      id,
      AppNotification.fromJson(raw).copyWith(read: true).toJson(),
    );
  }

  Future<void> markAllRead() async {
    final unread = all().where((n) => !n.read).toList();
    for (final n in unread) {
      await _db.put(
        AppConstants.boxNotifications,
        n.id,
        n.copyWith(read: true).toJson(),
      );
    }
  }

  Future<void> remove(String id) =>
      _db.delete(AppConstants.boxNotifications, id);

  Future<void> clearAll() => _db.clear(AppConstants.boxNotifications);

  int get unreadCount => all().where((n) => !n.read).length;
}
