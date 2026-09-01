import 'dart:js_interop';

import 'web_push_service_stub.dart';

WebPushPlatform createWebPushPlatform() => _WebPushPlatform();

class _WebPushPlatform implements WebPushPlatform {
  @override
  Future<bool> isGranted() async {
    try {
      return _getPermission() == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final result = await _requestPermission();
      return result == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showNotification(String title, String body, String url) async {
    try {
      _showNotif(title.toJS, body.toJS, url.toJS);
    } catch (_) {}
  }

  String _getPermission() {
    return _jsNotificationPermission().dartify()?.toString() ?? 'default';
  }

  Future<dynamic> _requestPermission() async {
    return _jsRequestNotificationPermission().dartify();
  }

  void _showNotif(JSString title, JSString body, JSString url) {
    _jsShowNotification(title, body, url);
  }
}

@JS('Notification.permission')
external JSString? _jsNotificationPermission();

@JS('Notification.requestPermission')
external JSObject _jsRequestNotificationPermission();

@JS('Notification')
external void _jsShowNotification(JSString title, JSString body, JSString url);
