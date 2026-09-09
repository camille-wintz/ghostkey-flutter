import '../client.dart';
import '../dto/bible.dart';

Future<BibleResponse> getBible(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/bible');
  return BibleResponse.fromJson(res.jsonObject());
}

/// The story-specific names in one chapter that the bible does not already
/// hold. A POST because it may run a model — but it is cached server-side
/// against the chapter's own `version`, so an unedited chapter costs nothing.
Future<NameScanResponse> scanChapterNames(String projectId, String documentId) async {
  final res = await apiFetch('/api/projects/$projectId/documents/$documentId/name-scan', method: 'POST');
  return NameScanResponse.fromJson(res.jsonObject());
}

/// File one name in the world bible. Accepting and declining are the same
/// call — a decline is `hidden: true` — and both make the name stop coming
/// back, because the sweep filters against the live bible.
Future<BibleEntityWriteResponse> createBibleEntity(
  String projectId, {
  required BibleEntityType type,
  required String name,
  bool hidden = false,
}) async {
  final res = await apiFetch('/api/projects/$projectId/bible/entities', method: 'POST', body: {
    'type': type.name,
    'name': name,
    if (hidden) 'hidden': true,
  });
  return BibleEntityWriteResponse.fromJson(res.jsonObject());
}
