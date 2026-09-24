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
///
/// A name the bible already answers to comes back as that card's id, not a
/// second card.
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

/// Edit the author's fields on one card. Only what is passed is written, so
/// an edit here cannot undo one made on the desk in between. `gmc` merges
/// per cell — an empty answer clears that cell. A name another card owns is
/// `name_taken`.
Future<BibleEntityWriteResponse> patchBibleEntity(
  String projectId,
  String entityId, {
  String? name,
  String? notes,
  String? description,
  Map<String, String>? gmc,
  bool? hidden,
}) async {
  final res = await apiFetch('/api/projects/$projectId/bible/entities/$entityId', method: 'PATCH', body: {
    'name': ?name,
    'notes': ?notes,
    'physical_description': ?description,
    'gmc': ?gmc,
    'hidden': ?hidden,
  });
  return BibleEntityWriteResponse.fromJson(res.jsonObject());
}
