// Unit test for the embed-channel timeout: a stalled native side (model load
// or inference never completing) must surface as a recoverable empty
// embedding — with a diagnosable lastError — instead of leaving the scan
// frozen on a forever-pending await.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/services/face_recognizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'embed channel timeout returns empty instead of hanging forever',
    () async {
      const channel = MethodChannel('artvault/biometrics');
      // Never completes — simulates a stalled native side.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) => Completer<dynamic>().future,
          );

      final rgb = Uint8List(112 * 112 * 3);
      final emb = await FaceRecognizer.instance.embeddingFromRgb(
        rgb,
        112,
        112,
        Rect.fromLTWH(10, 10, 50, 50),
        timeout: const Duration(milliseconds: 150),
      );

      expect(emb, isEmpty);
      expect(FaceRecognizer.instance.lastError, contains('timed out'));
    },
  );
}
