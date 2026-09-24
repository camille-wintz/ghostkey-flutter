import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/wisp.dart';
import '../server/jobs/job_run.dart';
import '../server/providers.dart';
import 'providers.dart';

/// Which of Wisp's runs: its job kind, and the subject its running slot is
/// keyed on (the analysis, for `book_analysis`; none otherwise).
typedef WispRunKey = JobRunKey;

WispRunKey analysisRunKey(String projectId, AnalysisId analysis) =>
    (projectId: projectId, kind: 'book_analysis', subject: analysis.wire);

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
        final analysis = AnalysisId.values.where((a) => a.wire == key.subject).firstOrNull;
        if (analysis != null) ref.invalidate(analysisProvider((projectId: key.projectId, analysis: analysis)));
      case 'reverse_outline':
        ref.invalidate(outlineProvider(key.projectId));
      case 'continuity':
        ref.invalidate(continuityProvider(key.projectId));
    }
  }
}

final wispRunProvider = NotifierProvider.autoDispose.family<WispRun, JobRunState, WispRunKey>(WispRun.new);
