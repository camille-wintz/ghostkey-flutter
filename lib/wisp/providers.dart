import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/jobs.dart';
import '../server/dto/wisp.dart';
import '../server/jobs/api.dart';
import '../server/wisp/api.dart';
import 'pages.dart';

// Wisp's server reads. Each is a cache probe — never a run — and is
// invalidated by `WispRun` when a run of it lands.

typedef AnalysisKey = ({String projectId, AnalysisId analysis});

/// How often a feed with a running job in it is asked again. The phone has no
/// job socket.
const Duration _poll = Duration(seconds: 3);

final analysisProvider = FutureProvider.autoDispose.family<AnalysisReport?, AnalysisKey>(
  (ref, key) => getAnalysis(key.projectId, key.analysis),
);

final outlineProvider = FutureProvider.autoDispose.family<OutlineResult, String>(
  (ref, projectId) => getOutline(projectId),
);

final continuityProvider = FutureProvider.autoDispose.family<ContinuityReport?, String>(
  (ref, projectId) => getContinuity(projectId),
);

/// The project's job feed, re-read while anything in it runs — what the line
/// editing list reads every chapter's pass off, in one request.
final wispJobsProvider = FutureProvider.autoDispose.family<List<JobSnapshot>, String>((ref, projectId) async {
  final jobs = await listJobs(projectId);
  if (jobs.any((j) => j.isRunning)) {
    final poll = Timer(_poll, ref.invalidateSelf);
    ref.onDispose(poll.cancel);
  }
  return jobs;
});

/// A continuity question, with the job row (or synthetic `cq-` snapshot) the
/// answer is posted against.
typedef OpenQuestion = ({String jobId, JobQuestion question});

/// Every unanswered continuity question — raised by a run in flight, or
/// outliving it on the cached report.
final continuityQuestionsProvider = Provider.autoDispose.family<List<OpenQuestion>, String>((ref, projectId) {
  final jobs = ref.watch(wispJobsProvider(projectId)).value ?? const [];
  return [
    for (final job in jobs.where((j) => j.kind == 'continuity'))
      for (final question in job.questions) (jobId: job.id, question: question),
  ];
});

/// Which of Wisp's tasks have a run going, read off the job feed — so the
/// room's list can say so before a page is opened.
final wispRunningTasksProvider = Provider.autoDispose.family<Set<WispPage>, String>((ref, projectId) {
  final jobs = ref.watch(wispJobsProvider(projectId)).value ?? const [];
  return {
    for (final job in jobs.where((j) => j.isRunning))
      ...switch ((job.kind, job.subject)) {
        ('edit_pass', _) => [WispPage.lineEditing],
        ('book_analysis', 'theme') => [WispPage.theme],
        ('book_analysis', 'pacing') => [WispPage.pacing],
        ('book_analysis', 'genre') => [WispPage.genre],
        ('continuity', _) => [WispPage.continuity],
        ('reverse_outline', _) => [WispPage.reverseOutline],
        _ => const <WispPage>[],
      },
  };
});
