import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/image_utils.dart';

/// Manages the app's private file store (images + documents).
///
/// Files live under `<app-documents>/artvault/` so they survive re-installs
/// on iOS and are sandboxed per-app on both platforms.
class FileStorageService {
  FileStorageService._();

  static final FileStorageService instance = FileStorageService._();

  Directory? _root;
  bool _ready = false;

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(docs.path, 'artvault'));
    await _root!.create(recursive: true);
    await Directory(p.join(_root!.path, 'images')).create(recursive: true);
    await Directory(p.join(_root!.path, 'thumbnails')).create(recursive: true);
    await Directory(p.join(_root!.path, 'documents')).create(recursive: true);
    await Directory(p.join(_root!.path, 'exports')).create(recursive: true);
    _ready = true;
  }

  bool get isReady => _ready;

  Directory get root {
    assert(_ready, 'FileStorageService.init() must be called first.');
    return _root!;
  }

  Directory get imagesDir => Directory(p.join(root.path, 'images'));
  Directory get thumbsDir => Directory(p.join(root.path, 'thumbnails'));
  Directory get documentsDir => Directory(p.join(root.path, 'documents'));
  Directory get exportsDir => Directory(p.join(root.path, 'exports'));

  String get imageExtension => Platform.isAndroid ? 'jpg' : 'jpg';

  /// Copies a picked image into the vault and returns its local path.
  Future<String> importImage(File source) async {
    final dir = imagesDir;
    final name = 'img_${DateTime.now().millisecondsSinceEpoch}.$imageExtension';
    final target = File(p.join(dir.path, name));
    final compressed = await ImageUtils.compress(source);
    await compressed.copy(target.path);
    if (compressed.path != source.path) {
      try {
        await compressed.delete();
      } catch (_) {}
    }
    return target.path;
  }

  /// Generates and stores a grid thumbnail. Returns its path.
  Future<String> makeThumbnail(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return imagePath;
    final thumb = await ImageUtils.thumbnail(file);
    return thumb.path;
  }

  /// Writes already-encoded image bytes (e.g. re-downloaded from the cloud
  /// after a reinstall) into the vault and returns the local path. The
  /// bytes are assumed to be a final JPEG, so no re-compression happens.
  Future<String> saveImageBytes(Uint8List bytes) async {
    final dir = imagesDir;
    final name = 'img_${DateTime.now().millisecondsSinceEpoch}.$imageExtension';
    final target = File(p.join(dir.path, name));
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  /// Imports a document (pdf/image/docx) into the vault.
  Future<String> importDocument(File source, String name) async {
    final safe = name.replaceAll(RegExp(r'[^\w.\- ]+'), '_');
    final target = File(
      p.join(
        documentsDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_$safe',
      ),
    );
    await source.copy(target.path);
    return target.path;
  }

  /// Writes re-downloaded document bytes into the vault (cloud recovery
  /// after a reinstall) and returns the local path.
  Future<String> saveDocumentBytes(Uint8List bytes, String name) async {
    final safe = name.replaceAll(RegExp(r'[^\w.\- ]+'), '_');
    final target = File(
      p.join(
        documentsDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_$safe',
      ),
    );
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<File?> fileForPath(String path) async {
    final f = File(path);
    if (await f.exists()) return f;
    return null;
  }

  Future<void> deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> deleteRecursively(String path) async {
    try {
      final d = Directory(path);
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }

  /// Total bytes used on disk, broken down by category
  /// (images & thumbnails / documents / exports & backups).
  Future<({int images, int documents, int exports})> storageBreakdown() async {
    Future<int> dirBytes(Directory dir) async {
      if (!dir.existsSync()) return 0;
      var total = 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
      return total;
    }

    return (
      images: await dirBytes(imagesDir),
      documents: await dirBytes(documentsDir),
      exports: await dirBytes(exportsDir),
    );
  }

  /// Convenience: total on-disk usage in bytes.
  Future<int> totalBytes() async {
    final breakdown = await storageBreakdown();
    return breakdown.images + breakdown.documents + breakdown.exports;
  }
}
