import 'dart:typed_data';

import '../client.dart';
import '../dto/json.dart';
import '../dto/media.dart';

// The media library's upload — POST /api/projects/:id/media/upload — raw
// bytes with the mime on the header, the filename and who added it on the
// query. The one thing on the server that turns a file into words, which is
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
    _ => 'application/octet-stream',
  };
}

/// Upload one file into the project's library. `origin` badges who added it
/// — "author" from a library, "chat" on the author's behalf.
Future<MediaItem> uploadMedia(
  String projectId,
  Uint8List bytes, {
  required String filename,
  String? contentType,
  String origin = 'author',
}) async {
  final query = Uri(queryParameters: {'filename': filename, if (origin != 'author') 'origin': origin}).query;
  final res = await apiFetch(
    '/api/projects/$projectId/media/upload?$query',
    method: 'POST',
    headers: {'Content-Type': contentType ?? mimeForFilename(filename)},
    body: bytes,
  );
  return MediaItem.fromJson(asJson(res.jsonObject()['item']));
}
