import 'dart:typed_data';

import '../client.dart';
import '../dto/json.dart';
import '../dto/media.dart';

// The series' media library, reached through any of its books —
// /api/projects/:id/media/**. Uploads are raw bytes with the mime on the
// header and the filename, folder and who added it on the query; the upload
// is also the one thing on the server that turns a file into words, which is
// why the chat sends a file here rather than reading it itself.

const String docxMimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
const String pdfMimeType = 'application/pdf';

/// The mime the server should read a file as, from its extension; the
/// generic one otherwise, and the server falls back to the extension itself.
String mimeForFilename(String filename) {
  final dot = filename.lastIndexOf('.');
  final ext = dot < 0 ? '' : filename.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'docx' => docxMimeType,
    'pdf' => pdfMimeType,
    'txt' => 'text/plain',
    'md' || 'markdown' => 'text/markdown',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'application/octet-stream',
  };
}

/// The whole library: every live item, newest first, and the folders.
Future<MediaLibrary> listMedia(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/media');
  return MediaLibrary.fromJson(res.jsonObject());
}

/// A keyword search — a read, ungated. [folderId] searches one folder,
/// [unfiledOnly] only what is in none; neither searches everywhere.
Future<List<MediaSearchHit>> searchMedia(
  String projectId,
  String query, {
  List<String> kinds = const ['image'],
  String? folderId,
  bool unfiledOnly = false,
  int topK = 50,
}) async {
  final res = await apiFetch('/api/projects/$projectId/media/search', method: 'POST', body: {
    'query': query,
    'mode': 'keyword',
    'kinds': kinds,
    if (folderId != null) 'folder_id': folderId else if (unfiledOnly) 'folder_id': null,
    'top_k': topK,
  });
  return asJsonList(res.jsonObject()['hits']).map(MediaSearchHit.fromJson).toList();
}

/// Upload one file into the library. `origin` badges who added it —
/// "author" from a library, "chat" on the author's behalf. [folderId] files
/// it at once.
Future<MediaItem> uploadMedia(
  String projectId,
  Uint8List bytes, {
  required String filename,
  String? contentType,
  String? folderId,
  String origin = 'author',
}) async {
  final query = Uri(queryParameters: {
    'filename': filename,
    'folder_id': ?folderId,
    if (origin != 'author') 'origin': origin,
  }).query;
  final res = await apiFetch(
    '/api/projects/$projectId/media/upload?$query',
    method: 'POST',
    headers: {'Content-Type': contentType ?? mimeForFilename(filename)},
    body: bytes,
  );
  return MediaItem.fromJson(asJson(res.jsonObject()['item']));
}

/// The picture sizes a draw can ask for.
enum DrawSize { square, portrait, landscape }

/// Draw a picture from words into the library. The server owns the whole
/// draw — the plan gate, one `image_generation`, the series' art direction —
/// and answers with an ordinary image item. Minutes, sometimes.
Future<MediaItem> drawMedia(
  String projectId, {
  required String prompt,
  DrawSize size = DrawSize.square,
  String? folderId,
}) async {
  final res = await apiFetch('/api/projects/$projectId/media/draw', method: 'POST', body: {
    'prompt': prompt,
    'size': size.name,
    'folder_id': ?folderId,
  });
  return MediaItem.fromJson(asJson(res.jsonObject()['item']));
}

/// One item, whole body, and how many bible cards show it.
Future<MediaItemRead> getMediaItem(String projectId, String itemId) async {
  final res = await apiFetch('/api/projects/$projectId/media/$itemId');
  return MediaItemRead.fromJson(res.jsonObject());
}

/// Retitle an item, or move it: [folderId] into a folder, [unfile] out of
/// every folder (the wire's explicit `folder_id: null`).
Future<MediaItem> patchMediaItem(
  String projectId,
  String itemId, {
  String? title,
  String? folderId,
  bool unfile = false,
}) async {
  final res = await apiFetch('/api/projects/$projectId/media/$itemId', method: 'PATCH', body: {
    'title': ?title,
    if (folderId != null) 'folder_id': folderId else if (unfile) 'folder_id': null,
  });
  return MediaItem.fromJson(asJson(res.jsonObject()['item']));
}

/// Remove an item from the library — off every board and card it was on.
Future<void> deleteMediaItem(String projectId, String itemId) async {
  await apiFetch('/api/projects/$projectId/media/$itemId', method: 'DELETE');
}

/// A new folder. A name the series already has is `name_taken` (409).
Future<MediaFolder> createMediaFolder(String projectId, String name) async {
  final res = await apiFetch('/api/projects/$projectId/media/folders', method: 'POST', body: {'name': name});
  return MediaFolder.fromJson(asJson(res.jsonObject()['folder']));
}

Future<MediaFolder> patchMediaFolder(String projectId, String folderId, {String? name, int? sortIndex}) async {
  final res = await apiFetch('/api/projects/$projectId/media/folders/$folderId', method: 'PATCH', body: {
    'name': ?name,
    'sort_index': ?sortIndex,
  });
  return MediaFolder.fromJson(asJson(res.jsonObject()['folder']));
}

/// Delete a folder. Its items stay in the library, unfiled.
Future<void> deleteMediaFolder(String projectId, String folderId) async {
  await apiFetch('/api/projects/$projectId/media/folders/$folderId', method: 'DELETE');
}
