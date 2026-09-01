import 'web_push_service_stub.dart'
    if (dart.library.js_interop) 'web_push_service_web.dart';

/// Web push notification registration and management.
/// Only functional on web — no-ops on mobile via conditional imports.
class WebPushService {
  WebPushService._();
  static final WebPushService instance = WebPushService._();

  final WebPushPlatform _platform = createWebPushPlatform();

  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  Future<void> init() async {
    _permissionGranted = await _platform.isGranted();
  }

  Future<bool> requestPermission() async {
    final granted = await _platform.requestPermission();
    _permissionGranted = granted;
    return granted;
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? url,
  }) async {
    if (!_permissionGranted) return;
    await _platform.showNotification(title, body, url ?? '/');
  }
}
