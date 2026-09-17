import '../client.dart';
import '../dto/json.dart';
import '../dto/plan.dart';

// /api/projects/:id/story-maps and /authored-outline — the author's plan.

/// Every map of the project, both sources, newest first. There is no read by
/// id: a board is found in this list.
Future<List<StoryMap>> listStoryMaps(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/story-maps');
  return asJsonList(res.jsonObject()['story_maps']).map(StoryMap.fromJson).toList();
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
