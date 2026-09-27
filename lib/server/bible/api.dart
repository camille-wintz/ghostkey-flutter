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
/// per cell — an empty answer clears that cell. `ties` replaces the card's
/// whole list, in order. A name another card owns is `name_taken`.
Future<BibleEntityWriteResponse> patchBibleEntity(
  String projectId,
  String entityId, {
  String? name,
  String? notes,
  String? description,
  Map<String, String>? gmc,
  List<BibleEntityTie>? ties,
  bool? hidden,
}) async {
  final res = await apiFetch('/api/projects/$projectId/bible/entities/$entityId', method: 'PATCH', body: {
    'name': ?name,
    'notes': ?notes,
    'physical_description': ?description,
    'gmc': ?gmc,
    'ties': ?ties?.map((t) => t.toJson()).toList(),
    'hidden': ?hidden,
  });
  return BibleEntityWriteResponse.fromJson(res.jsonObject());
}

/// Write a card's physical description from its own portrait. Only text
/// comes back — nothing is stored; the caller saves it through
/// [patchBibleEntity] like anything typed. Empty when the model saw no one
/// in the picture; `no_portrait` when the card has none it can open.
Future<String> describeEntityPortrait(String projectId, String entityId) async {
  final res = await apiFetch('/api/projects/$projectId/bible/entities/$entityId/describe-portrait', method: 'POST');
  return (res.jsonObject()['description'] as String? ?? '').trim();
}

/// One step of the dossier interview. The server is stateless: [asked] is
/// every label this sitting has asked. An [answer] to [answering] is filed
/// into the dossier verbatim under its heading before the next question is
/// asked; `next: false` files and stops, and answers null. `dossier_full`
/// when the answer would not fit — nothing is filed then.
Future<InterviewQuestion?> interviewEntity(
  String projectId,
  String entityId, {
  InterviewQuestion? answering,
  String? answer,
  required List<String> asked,
  bool next = true,
}) async {
  final res = await apiFetch('/api/projects/$projectId/bible/entities/$entityId/interview', method: 'POST', body: {
    if (answering != null && answer != null)
      'answer': {'label': answering.label, 'heading': answering.heading, 'text': answer},
    'asked': asked.length > 100 ? asked.sublist(asked.length - 100) : asked,
    'next': next,
  });
  final question = res.jsonObject()['question'];
  return question is Map<String, dynamic> ? InterviewQuestion.fromJson(question) : null;
}
