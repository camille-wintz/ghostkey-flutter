import '../client.dart';
import '../dto/json.dart';
import '../dto/plan.dart';

// The author's plan: /api/story-templates, /api/projects/:id/story-maps (the
// boards, and one card at a time on them) and /authored-outline (the prose,
// and the proposal or changeset made from a plan).

/// Every map of the project, both sources, newest first. There is no read by
/// id: a board is found in this list.
Future<List<StoryMap>> listStoryMaps(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/story-maps');
  return asJsonList(res.jsonObject()['story_maps']).map(StoryMap.fromJson).toList();
}

/// The structures a board can be started on.
Future<List<StoryTemplate>> listStoryTemplates() async {
  final res = await apiFetch('/api/story-templates');
  return asJsonList(res.jsonObject()['templates']).map(StoryTemplate.fromJson).toList();
}

String _board(String projectId, String mapId) => '/api/projects/$projectId/story-maps/${Uri.encodeComponent(mapId)}';

StoryMap _storyMap(ApiResponse res) => StoryMap.fromJson(asJson(res.jsonObject()['story_map']));

StoryCardWrite _cardWrite(ApiResponse res) {
  final json = res.jsonObject();
  return (board: StoryMap.fromJson(asJson(json['story_map'])), cardId: asString(json['card_id']));
}

/// Start a board — on a structure (a structure already started answers with
/// the board that is there), or blank when [templateId] is null.
Future<StoryMap> createStoryMap(String projectId, {String? templateId, String? name}) async {
  final res = await apiFetch(
    '/api/projects/$projectId/story-maps',
    method: 'POST',
    body: {'template_id': templateId, 'name': ?name},
  );
  return _storyMap(res);
}

/// Name a board, or clear the name back to its structure's with null.
Future<StoryMap> renameStoryMap(String projectId, String mapId, String? name) async {
  final res = await apiFetch(_board(projectId, mapId), method: 'PUT', body: {'name': name});
  return _storyMap(res);
}

Future<void> deleteStoryMap(String projectId, String mapId) async {
  await apiFetch(_board(projectId, mapId), method: 'DELETE');
}

/// Add a card (or, with [label], a label) at the end of the board.
Future<StoryCardWrite> addStoryCard(String projectId, String mapId, {bool label = false}) async {
  final res = await apiFetch('${_board(projectId, mapId)}/cards', method: 'POST', body: {if (label) 'kind': 'label'});
  return _cardWrite(res);
}

/// Edit one card. Only what is passed is sent; the server owns what a move
/// or a relink does to the chains.
Future<StoryMap> patchStoryCard(
  String projectId,
  String mapId,
  String cardId, {
  String? title,
  String? description,
  bool move = false,
  String? afterId,
  bool? startsChain,
}) async {
  final res = await apiFetch(
    '${_board(projectId, mapId)}/cards/${Uri.encodeComponent(cardId)}',
    method: 'PATCH',
    body: {
      'title': ?title,
      'description': ?description,
      if (move) 'after_id': afterId,
      'starts_chain': ?startsChain,
    },
  );
  return _storyMap(res);
}

Future<StoryMap> deleteStoryCard(String projectId, String mapId, String cardId) async {
  final res = await apiFetch('${_board(projectId, mapId)}/cards/${Uri.encodeComponent(cardId)}', method: 'DELETE');
  return _storyMap(res);
}

/// Copy a card straight after itself.
Future<StoryCardWrite> duplicateStoryCard(String projectId, String mapId, String cardId) async {
  final res = await apiFetch(
    '${_board(projectId, mapId)}/cards/${Uri.encodeComponent(cardId)}/duplicate',
    method: 'POST',
  );
  return _cardWrite(res);
}

Future<AuthoredOutline> getAuthoredOutline(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/authored-outline');
  return AuthoredOutline.fromJson(res.jsonObject());
}

/// Save the outline's text alone — the PUT is partial per key, so the
/// proposal is left to the server's own rule (a changed text voids a proposal
/// made from it). Last-write-wins: the route takes no version.
Future<AuthoredOutline> putAuthoredOutlineText(String projectId, String text) async {
  final res = await apiFetch('/api/projects/$projectId/authored-outline', method: 'PUT', body: {'text': text});
  return AuthoredOutline.fromJson(res.jsonObject());
}

/// Save the proposal alone — the whole tree, as the desk does.
Future<AuthoredOutline> putProposal(String projectId, List<ProposalEntry> chapters) async {
  final res = await apiFetch(
    '/api/projects/$projectId/authored-outline',
    method: 'PUT',
    body: {'chapters': chapters.map((e) => e.toJson()).toList()},
  );
  return AuthoredOutline.fromJson(res.jsonObject());
}

/// Throw the pending proposal or changeset away. The plan stays.
Future<AuthoredOutline> dismissProposal(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/authored-outline/proposal', method: 'DELETE');
  return AuthoredOutline.fromJson(res.jsonObject());
}

/// Turn the proposal into chapters, in a new draft. [draftName] null lets the
/// server name it (an empty book's draft keeps its own name).
Future<CommitResult> commitProposal(String projectId, {String? draftName}) async {
  final res = await apiFetch(
    '/api/projects/$projectId/authored-outline/commit',
    method: 'POST',
    body: {'name': ?draftName},
  );
  return CommitResult.fromJson(res.jsonObject());
}

/// Project the approved ops into a chapter proposal — no model call.
Future<AuthoredOutline> applyChangeset(String projectId, List<ChangesetOp> ops) async {
  final res = await apiFetch(
    '/api/projects/$projectId/authored-outline/apply-changeset',
    method: 'POST',
    body: {'ops': ops.map((op) => op.toJson()).toList()},
  );
  return AuthoredOutline.fromJson(res.jsonObject());
}
