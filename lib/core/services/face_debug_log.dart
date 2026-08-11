import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// On-device debug log for the face-unlock pipeline.
///
/// `debugPrint` output never reaches logcat on some OEM builds (vivo), which
/// made the enrollment bug invisible. Milestones are appended to a plain file
/// that can be pulled with:
///
///     adb shell run-as com.artvault.artvault cat files/face_debug.log
class FaceDebugLog {
  FaceDebugLog._();

  static final FaceDebugLog instance = FaceDebugLog._();

  File? _file;

  Future<File?> _target() async {
    if (_file != null) return _file;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/face_debug.log');
    } catch (_) {
      _file = null;
    }
    return _file;
  }

  Future<void> log(String line) async {
    final f = await _target();
    if (f == null) return;
    try {
      await f.writeAsString(
        '${DateTime.now().toIso8601String()} $line\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }
}
