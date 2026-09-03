/// Native (mobile/desktop) shim — re-exports dart:io so the rest of the
/// codebase can import this file instead of `dart:io` directly.
library;

export 'dart:io'
    show
        File,
        Directory,
        Platform,
        HttpOverrides,
        HttpClient,
        HttpClientRequest,
        HttpClientResponse,
        SocketException,
        Process,
        IOSink,
        FileMode,
        RandomAccessFile;
