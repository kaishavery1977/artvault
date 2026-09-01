/// Conditional import: exports dart:io on native platforms, web stubs on web.
export 'io_shim_web.dart'
    if (dart.library.io) 'io_shim_native.dart';
