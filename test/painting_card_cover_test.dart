// Widget tests for the card cover fallback: a grid/list card must render the
// first existing local image when coverImagePath is empty or its file is
// gone, instead of showing the "no image" placeholder. The detail screen
// already falls back to painting.images — the cards now mirror that.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/data/models/painting.dart';
import 'package:artvault/features/gallery/painting_card.dart';

import 'helpers.dart';

/// A real 1x1 PNG so Image.file decodes without errors in the test.
final List<int> _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Painting _painting({required String cover, required List<String> images}) =>
    Painting(
      id: 'p1',
      title: 'Test',
      artistId: 'a1',
      artistName: 'Artist',
      coverImagePath: cover,
      coverImageUrl: '',
      images: images,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// Creates a real temp image. Must run inside [WidgetTester.runAsync] —
/// real file IO never completes under flutter_test's FakeAsync zone.
Future<String> _tempImage(WidgetTester tester) async {
  late String path;
  late Directory dir;
  await tester.runAsync(() async {
    dir = await Directory.systemTemp.createTemp('cover_test');
    final img = File('${dir.path}/img.png')..writeAsBytesSync(_tinyPng);
    path = img.path;
  });
  // Synchronous cleanup — a Future-based delete would hang the teardown
  // under FakeAsync.
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
  return path;
}

void main() {
  setUpAll(disableRuntimeFontFetching);

  testWidgets('grid card falls back to the first existing image when the '
      'cover is empty', (tester) async {
    final img = await _tempImage(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [...appOverrides(introShown: true)],
        child: MaterialApp(
          home: Scaffold(
            body: PaintingGridCard(
              painting: _painting(cover: '', images: [img]),
            ),
          ),
        ),
      ),
    );
    // Bounded pumps so flutter_animate's zero-duration timers fire before
    // teardown.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, img);
  });

  testWidgets('grid card falls back when the cover file is gone',
      (tester) async {
    final img = await _tempImage(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [...appOverrides(introShown: true)],
        child: MaterialApp(
          home: Scaffold(
            body: PaintingGridCard(
              painting: _painting(
                cover: '/nonexistent/cover.png',
                images: [img],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, img);
  });

  testWidgets('list tile falls back to the first existing image',
      (tester) async {
    final img = await _tempImage(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaintingListTile(
            painting: _painting(cover: '', images: [img]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, img);
  });
}
