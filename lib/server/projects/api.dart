import 'dart:typed_data';

import '../../offline/mirror.dart';
import '../client.dart';
import '../dto/jobs.dart';
import '../dto/json.dart';
import '../dto/projects.dart';

// The shelf, a project's detail and a document are the reads the offline
// mirror keeps: served from the phone when the server can't be reached.

Future<List<ProjectMeta>> listProjects(String? folderId) async {
  final path = folderId == null
      ? '/api/projects'
      : '/api/projects?folder_id=${Uri.encodeQueryComponent(folderId)}';
  final json = await mirror.readThrough(
    'projects:${folderId ?? 'root'}',
    () async => (await apiFetch(path, timeout: mirroredReadTimeout)).jsonObject(),
  );
  return asJsonList(json['projects']).map(ProjectMeta.fromJson).toList();
}

Future<ProjectFull> getProject(String id) async {
  final json = await mirror.readThrough(
    'project:$id',
    () async => (await apiFetch('/api/projects/$id', timeout: mirroredReadTimeout)).jsonObject(),
  );
  return ProjectFull.fromJson(json);
}

/// `starterChapter` asks the server to create the manuscript's first empty
/// chapter, so a new book opens on something to write in.
Future<ProjectMeta> createProject({
  required String name,
  String? title,
  String? folderId,
  bool starterChapter = false,
}) async {
  final res = await apiFetch('/api/projects', method: 'POST', body: {
    'name': name,
    'title': ?title,
    'folder_id': ?folderId,
    if (starterChapter) 'starter_chapter': true,
  });
  return ProjectMeta.fromJson(asJson(res.jsonObject()['project']));
}

/// Chapter ordering is NOT patched here — it belongs to a draft
/// (see [patchDraftChapters]). `notes` is the ordered note list; the server
/// derives its internal note_order from array position.
Future<ProjectMeta> patchProject(
  String id, {
  String? name,
  String? title,
  String? description,
  String? author,
  String? coverFilename,
  TypographyMode? typography,
  List<DocumentSummary>? notes,
}) async {
  final res = await apiFetch('/api/projects/$id', method: 'PATCH', body: {
    'name': ?name,
    'title': ?title,
    'description': ?description,
    'author': ?author,
    'cover_filename': ?coverFilename,
    'typography': ?typography?.name,
    'notes': ?notes?.map((n) => n.toJson()).toList(),
  });
  return ProjectMeta.fromJson(asJson(res.jsonObject()['project']));
}

/// Rewrites one draft's chapter ordering. `baseVersion` makes the write
/// conditional on the draft still being at that version: a reorder made
/// against a tree another device has since rewritten is refused with 409
/// `version_conflict` rather than silently undoing their work.
Future<DraftSummary> patchDraftChapters(
  String projectId,
  String draftId,
  List<ChaptersListEntry> chapters, {
  int? baseVersion,
}) async {
  final res = await apiFetch('/api/projects/$projectId/drafts/$draftId', method: 'PATCH', body: {
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'base_version': ?baseVersion,
  });
  return DraftSummary.fromJson(asJson(res.jsonObject()['draft']));
}

Future<void> deleteProject(String id) async {
  await apiFetch('/api/projects/$id', method: 'DELETE');
}

/// Sums the words across every chapter of the active draft server-side.
Future<int> getProjectWordCount(String projectId) async {
  final res = await apiFetch('/api/word-count', method: 'POST', body: {'project_id': projectId});
  return asInt(res.jsonObject()['word_count']);
}

Future<DocumentDto> createDocument(
  String projectId, {
  required DocumentKind kind,
  required String filename,
  String content = '',
}) async {
  final res = await apiFetch('/api/projects/$projectId/documents', method: 'POST', body: {
    'kind': kind.name,
    'filename': filename,
    'content': content,
  });
  return _rememberDocument(projectId, asJson(res.jsonObject()['document']));
}

Future<DocumentDto> getDocument(String projectId, String documentId) async {
  final json = await mirror.readThrough(
    _documentKey(projectId, documentId),
    () async => asJson(
      (await apiFetch('/api/projects/$projectId/documents/$documentId', timeout: mirroredReadTimeout))
          .jsonObject()['document'],
    ),
    version: (json) => asInt(json['version']),
  );
  return DocumentDto.fromJson(json);
}

String _documentKey(String projectId, String documentId) => 'document:$projectId:$documentId';

/// A write's answer is the newest copy of the document: the offline copy
/// takes it, or a chapter saved and then opened offline would open on the
/// words from before the save.
Future<DocumentDto> _rememberDocument(String projectId, Json json) async {
  final doc = DocumentDto.fromJson(json);
  await mirror.remember(_documentKey(projectId, doc.id), json, version: doc.version);
  return doc;
}

/// `baseVersion` makes the write land only while the document is still at
/// that version; a miss is 409 `version_conflict`. Omitted, last-write-wins.
Future<DocumentDto> putDocument(String projectId, String documentId, String content, {int? baseVersion}) async {
  final res = await apiFetch(
    '/api/projects/$projectId/documents/$documentId',
    method: 'PUT',
    body: {'content': content, 'base_version': ?baseVersion},
  );
  return _rememberDocument(projectId, asJson(res.jsonObject()['document']));
}

Future<DocumentDto> renameDocument(String projectId, String documentId, String filename) async {
  final res = await apiFetch(
    '/api/projects/$projectId/documents/$documentId',
    method: 'PATCH',
    body: {'filename': filename},
  );
  return _rememberDocument(projectId, asJson(res.jsonObject()['document']));
}

Future<void> deleteDocument(String projectId, String documentId) async {
  await apiFetch('/api/projects/$projectId/documents/$documentId', method: 'DELETE');
}

Future<AssetMeta> uploadAsset(String projectId, String filename, String contentType, Uint8List bytes) async {
  final res = await apiFetch(
    '/api/projects/$projectId/assets?filename=${Uri.encodeQueryComponent(filename)}',
    method: 'POST',
    headers: {'Content-Type': contentType},
    body: bytes,
  );
  return AssetMeta.fromJson(asJson(res.jsonObject()['asset']));
}

/// Sets the cover the way the desktop does: the image goes up as a project
/// asset, then `cover_filename` names it, which is also what makes the server
/// build the thumbnail and the blurred backdrop. Assets are immutable, so each
/// cover gets a fresh name rather than colliding with the one it replaces.
Future<ProjectMeta> setProjectCover(String projectId, Uint8List bytes, {required String extension}) async {
  final ext = extension.toLowerCase();
  final contentType = switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
  final asset = await uploadAsset(projectId, 'cover-${DateTime.now().millisecondsSinceEpoch}.$ext', contentType, bytes);
  return patchProject(projectId, coverFilename: asset.filename);
}

Future<ProjectMeta> removeProjectCover(String projectId) => patchProject(projectId, coverFilename: '');

/// The publish formats the phone can save. PDF is left out: the server
/// sends print-ready HTML for it and each client renders the PDF itself, and
/// this app carries no HTML → PDF renderer.
enum ExportFormat {
  docx('docx', docxMime),
  epub('epub', 'application/epub+zip'),
  txt('txt', 'text/plain');

  const ExportFormat(this.extension, this.mimeType);
  final String extension;
  final String mimeType;
}

/// GET /api/projects/{id}/export/{format} — the whole manuscript assembled
/// server-side in reading order. One-way: nothing reads these back.
Future<Uint8List> exportProject(String projectId, ExportFormat format, {bool includeNotes = true}) async {
  final query = includeNotes ? '' : '?notes=false';
  final res = await apiFetch('/api/projects/$projectId/export/${format.extension}$query');
  return res.bodyBytes;
}

/// The content types the phone sends to the import route. The server reads
/// the bytes, not this header; it is sent so a request says what it carries.
const docxMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
const epubMime = 'application/epub+zip';

class DocxImportStart {
  const DocxImportStart({required this.project, required this.job});
  final ProjectMeta project;
  final JobSnapshot job;
}

/// POST /api/projects/{id}/import-manuscript — start a bulk chapter import.
/// The route also takes a zipped Scrivener project; the phone offers a .docx
/// or an .epub. The chapters are written by a `manuscript_import` job; follow
/// the returned job.
Future<DocxImportStart> importProjectDocx(
  String projectId,
  Uint8List bytes,
  String filename, {
  String mimeType = docxMime,
}) async {
  final res = await apiFetch(
    '/api/projects/$projectId/import-manuscript?name=${Uri.encodeQueryComponent(filename)}',
    method: 'POST',
    headers: {'Content-Type': mimeType},
    body: bytes,
  );
  final json = res.jsonObject();
  return DocxImportStart(
    project: ProjectMeta.fromJson(asJson(json['project'])),
    job: JobSnapshot.fromJson(asJson(json['job'])),
  );
}

/// The project's Poltergeist plan, or null when the board was never opened.
Future<ProjectPlan?> getProjectPlan(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/plan');
  final plan = res.jsonObject()['plan'];
  return plan == null ? null : ProjectPlan.fromJson(asJson(plan));
}

Future<ProjectPlan> putProjectPlan(String projectId, ProjectPlan plan) async {
  final res = await apiFetch('/api/projects/$projectId/plan', method: 'PUT', body: {'plan': plan.toJson()});
  return ProjectPlan.fromJson(asJson(res.jsonObject()['plan']));
}
