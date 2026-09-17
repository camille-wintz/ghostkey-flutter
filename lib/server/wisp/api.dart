import '../client.dart';
import '../dto/json.dart';
import '../dto/wisp.dart';

/// GET /api/projects/{id}/analyses/{analysis} — the last run's report, or
/// null when none has run (or it is from an older format).
Future<AnalysisReport?> getAnalysis(String projectId, AnalysisId analysis) async {
  final res = await apiFetch('/api/projects/$projectId/analyses/${analysis.wire}');
  final report = res.jsonObject()['report'];
  return report is Map ? AnalysisReport.fromJson(asJson(report)) : null;
}

/// GET /api/projects/{id}/outline — every length of the reverse outline.
Future<OutlineResult> getOutline(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/outline');
  return OutlineResult.fromJson(res.jsonObject());
}

/// GET /api/projects/{id}/continuity — the cached report, or null. The cache
/// is dropped whenever the manuscript meaningfully changes.
Future<ContinuityReport?> getContinuity(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/continuity');
  final report = res.jsonObject()['report'];
  return report is Map ? ContinuityReport.fromJson(asJson(report)) : null;
}
