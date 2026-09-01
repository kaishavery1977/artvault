/// Web shim — provides minimal stubs for dart:io types so the codebase
/// compiles to Web without errors.  On web these are no-ops; real file I/O
/// only happens on native.
import 'dart:typed_data';

/// Stub [File] — enough surface area so existing code compiles.
class File extends FileSystemEntity {
  File(String path) : super(path);

  bool existsSync() => false;
  Future<bool> exists() async => false;
  int lengthSync() => 0;
  Future<int> length() async => 0;
  List<int> readAsBytesSync() => [];
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Future<File> writeAsBytes(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) async => this;
  Future<File> writeAsString(String contents, {FileMode mode = FileMode.write, bool flush = false}) async => this;
  String readAsStringSync() => '';
  Future<String> readAsString() async => '';
  Future<File> copy(String newPath) async => this;
  Future<File> rename(String newPath) async => this;
  DateTime lastModifiedSync() => DateTime.now();
  Future<DateTime> lastModified() async => DateTime.now();
  Directory get parent => Directory(path);
  File get absolute => this;
  Uri get uri => Uri.file(path);
  Future<void> delete({bool recursive = false}) async {}
  void deleteSync({bool recursive = false}) {}
}

/// Stub [Directory].
class Directory {
  final String path;
  Directory(this.path);

  bool existsSync() => false;
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
  Stream<FileSystemEntity> list({bool recursive = false, bool followLinks = true}) async* {}
  Future<void> delete({bool recursive = false}) async {}
}

/// Minimal [Platform] stub.
class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static String get pathSeparator => '/';
  static String get operatingSystem => 'web';
  static String get localeName => 'en';
}

/// Stub [HttpOverrides].
class HttpOverrides {
  static HttpOverrides? global;
}

/// Stub [HttpClient].
class HttpClient {
  Future<HttpClientRequest> getUrl(Uri url) async => HttpClientRequest();
  void close({bool force = false}) {}
}

/// Stub [HttpClientRequest].
class HttpClientRequest {
  Future<HttpClientResponse> close() async => HttpClientResponse();
}

/// Stub [HttpClientResponse].
class HttpClientResponse {
  Future<List<int>> unfolds() async => [];
}

/// Stub [SocketException].
class SocketException implements Exception {
  final String message;
  SocketException(this.message);
}

/// Stub [Process].
class Process {
  static Future<ProcessResult> run(String executable, List<String> arguments,
      {String? workingDirectory, Map<String, String>? environment}) async {
    return ProcessResult(0, 0, '', '');
  }
}

/// Stub [ProcessResult].
class ProcessResult {
  final int pid;
  final int exitCode;
  final String stdout;
  final String stderr;
  ProcessResult(this.pid, this.exitCode, this.stdout, this.stderr);
}

/// Stub [IOSink].
class IOSink {
  void add(List<int> data) {}
  void addError(Object error, [StackTrace? stackTrace]) {}
  Future<void> flush() async {}
  Future<void> get done async {}
  void close() {}
}

/// Stub [FileMode].
class FileMode {
  static const FileMode write = FileMode._();
  static const FileMode append = FileMode._();
  static const FileMode read = FileMode._();
  const FileMode._();
}

/// Stub [RandomAccessFile].
class RandomAccessFile {
  Future<void> close() async {}
}

/// Stub [FileSystemEntity].
class FileSystemEntity {
  final String path;
  FileSystemEntity(this.path);
}
