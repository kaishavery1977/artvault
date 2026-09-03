import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'app_logger.dart';

/// Manages file storage in the user's personal Google Drive.
///
/// Files live under an `ArtVault/` root folder with subfolders for paintings,
/// documents and profile photos. All operations use the Drive REST API v3
/// with the user's OAuth token (from the existing Google Sign-In flow).
///
/// This is a lightweight wrapper — no `googleapis` package needed, just
/// HTTP requests against `https://www.googleapis.com/drive/v3/`.
class GoogleDriveService {
  GoogleDriveService._();

  static final GoogleDriveService instance = GoogleDriveService._();

  static const String _baseUrl = 'https://www.googleapis.com/drive/v3';
  static const String _uploadUrl = 'https://www.googleapis.com/upload/drive/v3';
  static const String _rootFolderName = 'ArtVault';
  static const String _paintingsFolder = 'paintings';
  static const String _documentsFolder = 'documents';
  static const String _profileFolder = 'profile';

  /// Cached root folder ID (resolved on first use).
  String? _rootFolderId;

  /// Current access token — refreshed automatically by google_sign_in.
  String? _accessToken;

  bool get isReady => _accessToken != null && _accessToken!.isNotEmpty;

  // -------------------------------------------------------------- Auth --

  /// The Drive API scope — allows reading/writing files in the user's Drive.
  static const List<String> _driveScopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];

  /// Obtains a Drive-scoped access token from the Google Sign-In account.
  /// Must be called after Google authentication succeeds, passing the
  /// [GoogleSignInAccount] that was returned by `GoogleSignIn.instance.authenticate()`.
  Future<bool> authenticate([GoogleSignInAccount? account]) async {
    if (kIsWeb) {
      // On web, the google_sign_in package doesn't expose a token directly;
      // the Drive REST API calls happen server-side or via the Firebase SDK.
      // For now, Drive storage is mobile/desktop only.
      return false;
    }
    try {
      // Request Drive-scoped authorization using the google_sign_in 7.x API.
      // The authorizationClient.authorizeScopes() method prompts the user
      // for Drive access if not already granted.
      final client = GoogleSignIn.instance.authorizationClient;
      final authz = await client.authorizeScopes(_driveScopes);
      _accessToken = authz.accessToken;
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        AppLogger.info('GoogleDriveService: authenticated with Drive scope');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.warning('GoogleDriveService: auth failed', error: e);
      return false;
    }
  }

  /// Signs out of Drive (clears cached tokens).
  void signOut() {
    _accessToken = null;
    _rootFolderId = null;
  }

  // ---------------------------------------------------------- Folder mgmt --

  /// Ensures the `ArtVault/` root folder exists in the user's Drive.
  /// Returns the folder ID. Creates it if missing.
  Future<String> ensureRootFolder() async {
    if (_rootFolderId != null) return _rootFolderId!;

    // Search for existing root folder.
    final existing = await _findFolderByName(_rootFolderName, null);
    if (existing != null) {
      _rootFolderId = existing;
      return existing;
    }

    // Create it.
    final id = await _createFolder(_rootFolderName, null);
    _rootFolderId = id;
    return id;
  }

  /// Ensures a subfolder exists under the root (e.g. `ArtVault/paintings`).
  Future<String> ensureSubfolder(String name) async {
    final rootId = await ensureRootFolder();
    final existing = await _findFolderByName(name, rootId);
    if (existing != null) return existing;
    return _createFolder(name, rootId);
  }

  /// Ensures a nested folder like `ArtVault/paintings/{paintingId}`.
  Future<String> ensurePaintingFolder(String paintingId) async {
    final paintingsId = await ensureSubfolder(_paintingsFolder);
    final existing = await _findFolderByName(paintingId, paintingsId);
    if (existing != null) return existing;
    return _createFolder(paintingId, paintingsId);
  }

  Future<String> ensureDocumentFolder(String paintingId) async {
    final docsId = await ensureSubfolder(_documentsFolder);
    final existing = await _findFolderByName(paintingId, docsId);
    if (existing != null) return existing;
    return _createFolder(paintingId, docsId);
  }

  Future<String> ensureProfileFolder(String uid) async {
    final profileId = await ensureSubfolder(_profileFolder);
    final existing = await _findFolderByName(uid, profileId);
    if (existing != null) return existing;
    return _createFolder(uid, profileId);
  }

  // --------------------------------------------------------------- Upload --

  /// Uploads [bytes] to Google Drive and returns the file ID.
  ///
  /// [drivePath] is a logical path like `paintings/{id}/cover.jpg`.
  /// The file is placed in the corresponding Drive folder structure.
  /// If a file with the same name already exists in that folder, it is
  /// overwritten (updated in place).
  Future<String?> uploadBytes({
    required String drivePath,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (!isReady) return null;
    try {
      final folderId = await _resolveFolderForPath(drivePath);
      final fileName = _fileNameFromPath(drivePath);

      // Check if a file with this name already exists in the target folder.
      final existingId = await _findFileByName(fileName, folderId);

      if (existingId != null) {
        // Update existing file content.
        return await _updateFileContent(existingId, bytes, contentType);
      } else {
        // Create new file.
        return await _createFile(fileName, folderId, bytes, contentType);
      }
    } catch (e) {
      AppLogger.warning(
        'GoogleDriveService: upload failed for $drivePath',
        error: e,
      );
      return null;
    }
  }

  // -------------------------------------------------------------- Download --

  /// Downloads a file from Google Drive by its file ID.
  Future<Uint8List?> downloadBytes(String fileId) async {
    if (!isReady || fileId.isEmpty) return null;
    try {
      final url = Uri.parse('$_baseUrl/files/$fileId?alt=media');
      final resp = await http.get(url, headers: _authHeaders());
      if (resp.statusCode == 200) return resp.bodyBytes;
      AppLogger.warning(
        'GoogleDriveService: download failed ${resp.statusCode}',
      );
      return null;
    } catch (e) {
      AppLogger.warning('GoogleDriveService: download error', error: e);
      return null;
    }
  }

  /// Downloads bytes from a Drive file identified by path (e.g. `paintings/{id}/cover.jpg`).
  Future<Uint8List?> downloadByPath(String drivePath) async {
    if (!isReady) return null;
    try {
      final folderId = await _resolveFolderForPath(drivePath);
      final fileName = _fileNameFromPath(drivePath);
      final fileId = await _findFileByName(fileName, folderId);
      if (fileId == null) return null;
      return downloadBytes(fileId);
    } catch (e) {
      AppLogger.warning('GoogleDriveService: downloadByPath failed', error: e);
      return null;
    }
  }

  // --------------------------------------------------------------- Delete --

  /// Deletes a file from Google Drive by its file ID.
  Future<void> deleteFile(String fileId) async {
    if (!isReady || fileId.isEmpty) return;
    try {
      final url = Uri.parse('$_baseUrl/files/$fileId');
      await http.delete(url, headers: _authHeaders());
    } catch (e) {
      AppLogger.warning('GoogleDriveService: delete failed', error: e);
    }
  }

  /// Deletes a file from Drive by its logical path.
  Future<void> deleteByPath(String drivePath) async {
    if (!isReady) return;
    try {
      final folderId = await _resolveFolderForPath(drivePath);
      final fileName = _fileNameFromPath(drivePath);
      final fileId = await _findFileByName(fileName, folderId);
      if (fileId != null) await deleteFile(fileId);
    } catch (_) {}
  }

  /// Deletes a folder and all its contents from Drive.
  Future<void> deleteFolder(String folderId) async {
    if (!isReady || folderId.isEmpty) return;
    try {
      await _deleteFolderRecursive(folderId);
    } catch (e) {
      AppLogger.warning('GoogleDriveService: deleteFolder failed', error: e);
    }
  }

  // ------------------------------------------------------------- Helpers --

  Map<String, String> _authHeaders() => {
    'Authorization': 'Bearer $_accessToken',
  };

  String _fileNameFromPath(String path) {
    final parts = path.split('/');
    return parts.last;
  }

  /// Resolves the Drive folder ID for a logical path like `paintings/{id}/cover.jpg`.
  Future<String> _resolveFolderForPath(String drivePath) async {
    final parts = drivePath.split('/');
    if (parts.length < 2) return ensureRootFolder();

    final category = parts[0]; // paintings, documents, profile
    final id = parts.length >= 2 ? parts[1] : '';

    switch (category) {
      case _paintingsFolder:
        if (id.isEmpty) return ensureSubfolder(_paintingsFolder);
        return ensurePaintingFolder(id);
      case _documentsFolder:
        if (id.isEmpty) return ensureSubfolder(_documentsFolder);
        return ensureDocumentFolder(id);
      case _profileFolder:
        if (id.isEmpty) return ensureSubfolder(_profileFolder);
        return ensureProfileFolder(id);
      default:
        return ensureRootFolder();
    }
  }

  // ------------------------------------------------- Drive API v3 wrappers --

  /// Finds a folder by name under [parentFolderId]. Returns null if not found.
  Future<String?> _findFolderByName(String name, String? parentFolderId) async {
    final query = StringBuffer(
      "mimeType='application/vnd.google-apps.folder' and name='$name' and trashed=false",
    );
    if (parentFolderId != null) {
      query.write(" and '$parentFolderId' in parents");
    }
    final url = Uri.parse(
      '$_baseUrl/files?q=${Uri.encodeComponent(query.toString())}&fields=files(id)&pageSize=1',
    );
    final resp = await http.get(url, headers: _authHeaders());
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>? ?? [];
    if (files.isEmpty) return null;
    return files[0]['id'] as String;
  }

  /// Creates a folder under [parentFolderId]. Returns the new folder ID.
  Future<String> _createFolder(String name, String? parentFolderId) async {
    final metadata = {
      'name': name,
      'mimeType': 'application/vnd.google-apps.folder',
      if (parentFolderId != null) 'parents': [parentFolderId],
    };
    final url = Uri.parse('$_baseUrl/files?fields=id');
    final resp = await http.post(
      url,
      headers: {..._authHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode(metadata),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(
        'Failed to create folder: ${resp.statusCode} ${resp.body}',
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['id'] as String;
  }

  /// Finds a file by name in a folder. Returns the file ID or null.
  Future<String?> _findFileByName(String name, String folderId) async {
    final query =
        "name='$name' and '$folderId' in parents and trashed=false and mimeType!='application/vnd.google-apps.folder'";
    final url = Uri.parse(
      '$_baseUrl/files?q=${Uri.encodeComponent(query)}&fields=files(id)&pageSize=1',
    );
    final resp = await http.get(url, headers: _authHeaders());
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>? ?? [];
    if (files.isEmpty) return null;
    return files[0]['id'] as String;
  }

  /// Creates a file in a folder. Returns the file ID.
  Future<String> _createFile(
    String name,
    String folderId,
    Uint8List bytes,
    String contentType,
  ) async {
    // Multipart upload.
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_uploadUrl?uploadType=multipart&fields=id'),
    );
    request.headers['Authorization'] = 'Bearer $_accessToken';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: name),
    );
    request.fields['metadata'] = jsonEncode({
      'name': name,
      'parents': [folderId],
    });

    final streamedResponse = await request.send();
    final resp = await http.Response.fromStream(streamedResponse);

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Failed to create file: ${resp.statusCode} ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['id'] as String;
  }

  /// Updates an existing file's content. Returns the file ID.
  Future<String> _updateFileContent(
    String fileId,
    Uint8List bytes,
    String contentType,
  ) async {
    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse('$_uploadUrl/files/$fileId?uploadType=multipart&fields=id'),
    );
    request.headers['Authorization'] = 'Bearer $_accessToken';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: 'file'),
    );
    request.fields['metadata'] = '{}';

    final streamedResponse = await request.send();
    final resp = await http.Response.fromStream(streamedResponse);

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Failed to update file: ${resp.statusCode} ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['id'] as String;
  }

  /// Recursively deletes a folder and its contents.
  Future<void> _deleteFolderRecursive(String folderId) async {
    // List all children.
    final query = "'$folderId' in parents and trashed=false";
    final url = Uri.parse(
      '$_baseUrl/files?q=${Uri.encodeComponent(query)}&fields=files(id,mimeType)&pageSize=1000',
    );
    final resp = await http.get(url, headers: _authHeaders());
    if (resp.statusCode != 200) return;

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>? ?? [];

    for (final file in files) {
      final id = file['id'] as String;
      final mime = file['mimeType'] as String? ?? '';
      if (mime == 'application/vnd.google-apps.folder') {
        await _deleteFolderRecursive(id);
      } else {
        await deleteFile(id);
      }
    }

    // Delete the folder itself.
    final delUrl = Uri.parse('$_baseUrl/files/$folderId');
    await http.delete(delUrl, headers: _authHeaders());
  }
}
