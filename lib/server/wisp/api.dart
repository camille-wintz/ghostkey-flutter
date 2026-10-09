import '../client.dart';
import '../dto/wisp.dart';

/// GET /api/projects/{id}/analyses/{analysis} — the last run's report (null
/// when none has run, or it is from an older format), cut to a preview below
/// `wisp.full_reports`. [analysis] is the wire id: an [AnalysisId]'s.
Future<AnalysisRead> getAnalysis(String projectId, String analysis) async {
  final res = await apiFetch('/api/projects/$projectId/analyses/$analysis');
  return AnalysisRead.fromJson(res.jsonObject());
}

/// GET /api/projects/{id}/outline — every length of the reverse outline.
Future<OutlineResult> getOutline(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/outline');
  return OutlineResult.fromJson(res.jsonObject());
}

/// GET /api/projects/{id}/continuity — the cached plot-hole report (null
/// when none), cut to a preview of one finding below `wisp.full_reports`. The
/// cache is dropped whenever the manuscript meaningfully changes. [chapter]
/// (a document id) reads that chapter's single-chapter report.
Future<ContinuityRead> getContinuity(String projectId, {String? chapter}) async {
  final query = chapter == null ? '' : '?chapter=${Uri.encodeQueryComponent(chapter)}';
  final res = await apiFetch('/api/projects/$projectId/continuity$query');
  return ContinuityRead.fromJson(res.jsonObject());
}

/// GET /api/projects/{id}/continuity/estimate — what a check of the whole
/// book, or of [chapter] against what precedes it, would cost in credits.
Future<ContinuityEstimate> getContinuityEstimate(String projectId, {String? chapter}) async {
  final query = chapter == null ? '' : '?chapter=${Uri.encodeQueryComponent(chapter)}';
  final res = await apiFetch('/api/projects/$projectId/continuity/estimate$query');
  return ContinuityEstimate.fromJson(res.jsonObject());
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
