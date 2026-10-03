import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/jobs.dart';
import '../server/dto/wisp.dart';
import '../server/jobs/api.dart';
import '../server/wisp/api.dart';
import 'access.dart';
import 'pages.dart';

// Wisp's server reads. Each is a cache probe — never a run — and is
// invalidated by `WispRun` when a run of it lands.

/// `analysis` is the wire id: an [AnalysisId]'s, or a beta reader's.
typedef AnalysisKey = ({String projectId, String analysis});

/// How often a feed with a running job in it is asked again. The phone has no
/// job socket.
const Duration _poll = Duration(seconds: 3);

final analysisProvider = FutureProvider.autoDispose.family<AnalysisRead, AnalysisKey>(
  (ref, key) => getAnalysis(key.projectId, key.analysis),
);

/// The beta readers' catalogue: who reads, and whose letter is waiting.
final betaReadersProvider = FutureProvider.autoDispose.family<List<ReaderCard>, String>(
  (ref, projectId) => getBetaReaders(projectId),
);

/// A reader and the book they read: `reader` is the cat id (`custard`).
typedef BetaPagesKey = ({String projectId, String reader});

/// One reader's comments on the book's pages. Stale with their letter, so a
/// landed beta read invalidates it beside [analysisProvider].
final betaReaderPagesProvider = FutureProvider.autoDispose.family<BetaReaderPages, BetaPagesKey>(
  (ref, key) => getBetaReaderPages(key.projectId, key.reader),
);

final outlineProvider = FutureProvider.autoDispose.family<OutlineResult, String>(
  (ref, projectId) => getOutline(projectId),
);

/// A plot-hole check's scope: [chapter] (a document id) against everything
/// before it, or the whole book when null.
typedef ContinuityKey = ({String projectId, String? chapter});

final continuityProvider = FutureProvider.autoDispose.family<ContinuityRead, ContinuityKey>(
  (ref, key) => getContinuity(key.projectId, chapter: key.chapter),
);

/// What a check of that scope would cost. Stale whenever a run lands — the
/// chapters it read are cached, so the next one costs less.
final continuityEstimateProvider = FutureProvider.autoDispose.family<ContinuityEstimate, ContinuityKey>(
  (ref, key) => getContinuityEstimate(key.projectId, chapter: key.chapter),
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

/// Every unanswered continuity question the job feed carries — raised by a
/// run in flight, or outliving it on the cached report until its job panel
/// card is closed. Closed or not, a waiting question stays on its finding in
/// the report (`ContinuityFinding.question`).
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
        ('book_analysis', final String s) when isBetaRead(s) => [WispPage.betaReaders],
        ('continuity', _) => [WispPage.continuity],
        ('reverse_outline', _) => [WispPage.reverseOutline],
        _ => const <WispPage>[],
      },
  };
});
