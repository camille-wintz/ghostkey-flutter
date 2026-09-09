import 'dart:typed_data';

import '../client.dart';
import '../dto/jobs.dart';
import '../dto/json.dart';
import '../dto/projects.dart';

Future<List<ProjectMeta>> listProjects(String? folderId) async {
  final path = folderId == null
      ? '/api/projects'
      : '/api/projects?folder_id=${Uri.encodeQueryComponent(folderId)}';
  final res = await apiFetch(path);
  return asJsonList(res.jsonObject()['projects']).map(ProjectMeta.fromJson).toList();
}

Future<ProjectFull> getProject(String id) async {
  final res = await apiFetch('/api/projects/$id');
  return ProjectFull.fromJson(res.jsonObject());
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
  List<DocumentSummary>? notes,
}) async {
  final res = await apiFetch('/api/projects/$id', method: 'PATCH', body: {
    'name': ?name,
    'title': ?title,
    'description': ?description,
    'author': ?author,
    'cover_filename': ?coverFilename,
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
  return DocumentDto.fromJson(asJson(res.jsonObject()['document']));
}

Future<DocumentDto> getDocument(String projectId, String documentId) async {
  final res = await apiFetch('/api/projects/$projectId/documents/$documentId');
  return DocumentDto.fromJson(asJson(res.jsonObject()['document']));
}

Future<DocumentDto> putDocument(String projectId, String documentId, String content) async {
  final res = await apiFetch(
    '/api/projects/$projectId/documents/$documentId',
    method: 'PUT',
    body: {'content': content},
  );
  return DocumentDto.fromJson(asJson(res.jsonObject()['document']));
}

Future<DocumentDto> renameDocument(String projectId, String documentId, String filename) async {
  final res = await apiFetch(
    '/api/projects/$projectId/documents/$documentId',
    method: 'PATCH',
    body: {'filename': filename},
  );
  return DocumentDto.fromJson(asJson(res.jsonObject()['document']));
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

/// The one content type the import route accepts.
const docxMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

class DocxImportStart {
  const DocxImportStart({required this.project, required this.job});
  final ProjectMeta project;
  final JobSnapshot job;
}

/// POST /api/projects/{id}/import-docx — start a bulk chapter import. The
/// chapters are written by a `docx_import` job; follow the returned job.
Future<DocxImportStart> importProjectDocx(String projectId, Uint8List bytes, String filename) async {
  final res = await apiFetch(
    '/api/projects/$projectId/import-docx?name=${Uri.encodeQueryComponent(filename)}',
    method: 'POST',
    headers: {'Content-Type': docxMime},
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
