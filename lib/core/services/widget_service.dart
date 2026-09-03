import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/repositories/painting_repository.dart';

/// Pushes a random painting from the vault to the Android home-screen widget.
class WidgetService {
  WidgetService._();
  static final instance = WidgetService._();

  static const _iOSName = 'ArtVaultWidget';
  static const _androidName = 'com.artvault.widget.PaintingWidget';
  static const _keyTitle = 'painting_title';
  static const _keyArtist = 'painting_artist';
  static const _keyImagePath = 'painting_image_path';

  /// Picks a random painting and saves its info for the widget to render.
  Future<void> updateWidget() async {
    if (kIsWeb) return;
    try {
      final paintings = PaintingRepository.instance.readAll();
      if (paintings.isEmpty) return;

      final p = paintings[math.Random().nextInt(paintings.length)];
      await HomeWidget.saveWidgetData<String>(_keyTitle, p.title);
      await HomeWidget.saveWidgetData<String>(_keyArtist, p.artistName);
      await HomeWidget.saveWidgetData<String>(_keyImagePath, p.coverImagePath);

      await HomeWidget.updateWidget(name: _androidName, iOSName: _iOSName);
    } catch (e) {
      debugPrint('WidgetService.updateWidget error: $e');
    }
  }
}
