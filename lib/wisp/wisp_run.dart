import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/jobs/job_run.dart';
import '../server/providers.dart';
import 'access.dart';
import 'providers.dart';

/// Which of Wisp's runs: its job kind, and the subject its running slot is
/// keyed on (the analysis, for `book_analysis`; none otherwise).
typedef WispRunKey = JobRunKey;

/// [analysis] is the wire id: an [AnalysisId]'s, or a beta reader's.
WispRunKey analysisRunKey(String projectId, String analysis) =>
    (projectId: projectId, kind: 'book_analysis', subject: analysis);

WispRunKey outlineRunKey(String projectId) => (projectId: projectId, kind: 'reverse_outline', subject: null);

WispRunKey continuityRunKey(String projectId) => (projectId: projectId, kind: 'continuity', subject: null);

/// One of Wisp's runs for a project, refreshing the page's read when it
/// lands. The reverse outline's run is tagged with the length it makes.
class WispRun extends JobRun {
  WispRun(super.key);

  @override
  Duration get patience => switch (key.kind) {
        'continuity' => const Duration(hours: 3),
        'book_analysis' => const Duration(minutes: 90),
        _ => const Duration(hours: 1),
      };

  @override
  void onLanded() {
    ref.invalidate(wispJobsProvider(key.projectId));
    ref.invalidate(quotaProvider);
    switch (key.kind) {
      case 'book_analysis':
        if (key.subject case final analysis?) {
          ref.invalidate(analysisProvider((projectId: key.projectId, analysis: analysis)));
          if (isBetaRead(analysis)) {
            ref.invalidate(betaReadersProvider(key.projectId));
            ref.invalidate(betaReaderPagesProvider(
              (projectId: key.projectId, reader: analysis.substring('beta_'.length)),
            ));
          }
        }
      case 'reverse_outline':
        ref.invalidate(outlineProvider(key.projectId));
      case 'continuity':
        ref.invalidate(continuityProvider(key.projectId));
    }
  }
}

final wispRunProvider = NotifierProvider.autoDispose.family<WispRun, JobRunState, WispRunKey>(WispRun.new);
