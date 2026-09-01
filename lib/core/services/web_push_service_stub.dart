/// Mobile stub — all methods are no-ops on mobile.
abstract class WebPushPlatform {
  Future<bool> isGranted();
  Future<bool> requestPermission();
  Future<void> showNotification(String title, String body, String url);
}

WebPushPlatform createWebPushPlatform() => _MobilePushPlatform();

class _MobilePushPlatform implements WebPushPlatform {
  @override
  Future<bool> isGranted() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> showNotification(String title, String body, String url) async {}
}
