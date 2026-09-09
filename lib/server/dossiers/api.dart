import '../client.dart';
import '../dto/bible.dart';
import '../dto/json.dart';

/// GET /api/projects/{id}/dossiers — every dossier the server has cached for
/// this book, keyed by world-bible entity key. A key that is absent has never
/// been generated. Server-generated only; building one is the
/// `entity_dossier` job.
Future<Map<String, Dossier>> getDossiers(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/dossiers');
  final map = asJson(res.jsonObject()['dossiers'] ?? const <String, dynamic>{});
  return {for (final entry in map.entries) entry.key: Dossier.fromJson(asJson(entry.value))};
}
