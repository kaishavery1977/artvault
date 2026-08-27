// Verifies the QR scanner's success pulse (green ring + check) through the
// REAL mobile_scanner pipeline: the platform method/event channels are mocked,
// but the controller, BarcodeCapture parsing, QrService payload parsing and
// the screen's own detection handler all run for real — so this test fails if
// the pulse stops rendering or the payload ever stops resolving.
//
// The barcode event is emitted on the same channel the Android plugin uses,
// carrying a genuine QrService.payloadFor(...) deep link.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:artvault/core/services/qr_service.dart';
import 'package:artvault/features/qr/qr_scan_screen.dart';

import 'helpers.dart';
import 'hive_test_harness.dart';

const _methodChannel = MethodChannel(
  'dev.steenbakker.mobile_scanner/scanner/method',
);
const _eventChannel = EventChannel(
  'dev.steenbakker.mobile_scanner/scanner/event',
);
const _orientationChannel = EventChannel(
  'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
);

const _successGreen = Color(0xFF22C55E);

/// A payload identical to what `QrService.payloadFor` embeds in a real
/// artwork QR code.
String _realPayload() => QrService.payloadFor(
  'p-7f3a91c2',
  title: 'Evening on the Canal',
  artistName: 'Clara Voss',
  price: 1200,
  currency: 'EUR',
  description: 'Oil on canvas, 2024',
);

void main() {
  setUpAll(disableRuntimeFontFetching);
  setUpAll(initTestHive);
  setUp(clearTestVault);

  late MockStreamHandlerEventSink barcodeSink;

  setUp(() {
    barcodeSink = _NullSink();

    messenger.setMockMethodCallHandler(_methodChannel, (call) async {
      switch (call.method) {
        // Camera permission already granted.
        case 'state':
          return 1;
        // Camera starts: Android surface-producer config.
        case 'start':
          return <String, Object?>{
            'textureId': 1,
            'cameraDirection': 1, // back
            'numberOfCameras': 1,
            'currentTorchState': 0, // off
            'size': {'width': 640.0, 'height': 480.0},
            'handlesCropAndRotation': true,
            'naturalDeviceOrientation': 'PORTRAIT_UP',
            'sensorOrientation': 90,
          };
        default:
          return null; // stop / toggleTorch / updateScanWindow / dispose…
      }
    });
    messenger.setMockStreamHandler(
      _eventChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          barcodeSink = events;
        },
        onCancel: (arguments) {},
      ),
    );
    messenger.setMockStreamHandler(
      _orientationChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {},
        onCancel: (arguments) {},
      ),
    );

    addTearDown(() {
      messenger.setMockMethodCallHandler(_methodChannel, null);
      messenger.setMockStreamHandler(_eventChannel, null);
      messenger.setMockStreamHandler(_orientationChannel, null);
      MobileScannerController.resetPlatformSessionOwner();
    });
  });

  testWidgets('a scanned ArtVault code flashes the success pulse', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: QrScanScreen()));
    // Let the controller attach + start the (mocked) camera.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // No pulse before a detection.
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    // The real event-channel message shape the Android plugin sends. The
    // detection hops through several async stream layers (event channel →
    // platform stream → controller broadcast → widget subscription), so pump
    // until the pulse actually renders (bounded).
    // The real event-channel message shape the Android plugin sends. The
    // detection hops through several async stream layers (event channel →
    // platform stream → controller broadcast → widget subscription); the
    // message is delivered on the real event loop, so emit inside runAsync
    // and then pump until the pulse actually renders (bounded).
    await tester.runAsync(() async {
      barcodeSink.success(<String, Object?>{
        'name': 'barcode',
        'data': <Map<String, Object?>>[
          {'rawValue': _realPayload(), 'format': 256, 'type': 7},
        ],
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    var pumps = 0;
    while (find.byIcon(Icons.check_rounded).evaluate().isEmpty && pumps < 40) {
      await tester.pump(const Duration(milliseconds: 25));
      pumps++;
    }

    // Green check icon + circular ring are on screen.
    final check = find.byIcon(Icons.check_rounded);
    expect(check, findsOneWidget);
    expect(
      tester.widget<Icon>(check).color,
      _successGreen,
      reason: 'the pulse must use the success green',
    );

    final ring = find.ancestor(
      of: check,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(ring, findsOneWidget, reason: 'the pulse must draw a circular ring');

    // The payload resolves: the artwork is not in the vault, so the preview
    // dialog offers to add it.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Add to vault'), findsOneWidget);
  });

  testWidgets('foreign QR codes are ignored — no pulse', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: QrScanScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    barcodeSink.success(<String, Object?>{
      'name': 'barcode',
      'data': <Map<String, Object?>>[
        {
          'rawValue': 'https://example.com/not-artvault',
          'format': 256,
          'type': 8,
        },
      ],
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.text('Add to vault'), findsNothing);
  });
}

/// Sink that discards events until the mock stream handler wires the real
/// one in (a detection before listen is attached would otherwise throw).
class _NullSink implements MockStreamHandlerEventSink {
  @override
  void success(Object? event) {}

  @override
  void error({required String code, String? message, Object? details}) {}

  @override
  void endOfStream() {}
}

/// Shortcut to the test binding's default messenger.
TestDefaultBinaryMessenger get messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
