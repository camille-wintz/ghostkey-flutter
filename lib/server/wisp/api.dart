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

/// POST /api/projects/{id}/continuity/answer — answer a finding's question
/// from the report (`question_id` is the finding's `question.id`). Same effect
/// as the job answer route, and it works after the question's job panel card
/// was closed. 404 `question_not_found` once it is no longer pending.
Future<void> answerContinuityQuestion(
  String projectId, {
  required String questionId,
  required String optionId,
  String? text,
}) async {
  await apiFetch(
    '/api/projects/$projectId/continuity/answer',
    method: 'POST',
    body: {'question_id': questionId, 'option_id': optionId, if (text != null && text.isNotEmpty) 'text': text},
  );
}
