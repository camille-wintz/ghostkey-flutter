import '../client.dart';
import '../dto/json.dart';
import '../dto/projects.dart';

/// GET /api/series — the caller's series, with live book counts. Read for one
/// reason on mobile: the shelf prints the series a book belongs to under its
/// title. An implicit series (one the author has not named) is not drawn.
Future<List<Series>> listSeries() async {
  final res = await apiFetch('/api/series');
  return asJsonList(res.jsonObject()['series']).map(Series.fromJson).toList();
}
