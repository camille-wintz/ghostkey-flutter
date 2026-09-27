import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/jobs.dart';
import '../server/jobs/api.dart';
import '../server/wisp/api.dart';
import 'providers.dart';

// The two doors to continuity's "which is the story?": a question on the job
// feed is answered against its row (or the synthetic `cq-` one), a finding's
// question from the report. Either answer stamps the report and drops the
// question from any row still holding it, so both reads are refetched — the
// report then shows the finding's resolution. Nothing is patched locally.

/// Answer a question the job feed carries, against the row it came on.
Future<void> answerFeedQuestion(
  WidgetRef ref,
  String projectId,
  OpenQuestion open,
  JobQuestionOption option,
  String? text,
) async {
  await answerJobQuestion(projectId, open.jobId, questionId: open.question.id, optionId: option.id, text: text);
  _refetch(ref, projectId);
}

/// Answer a finding's question from the report — the door that still works
/// once the question's job panel card was closed.
Future<void> answerReportQuestion(
  WidgetRef ref,
  String projectId,
  JobQuestion question,
  JobQuestionOption option,
  String? text,
) async {
  await answerContinuityQuestion(projectId, questionId: question.id, optionId: option.id, text: text);
  _refetch(ref, projectId);
}

void _refetch(WidgetRef ref, String projectId) {
  ref.invalidate(wispJobsProvider(projectId));
  ref.invalidate(continuityProvider(projectId));
}
