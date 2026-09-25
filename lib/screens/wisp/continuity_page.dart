import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../chat/quota_feature.dart';
import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../wisp/access.dart';
import '../../wisp/providers.dart';
import '../../wisp/wisp_run.dart';
import '../project/project_root.dart';
import 'continuity_report_view.dart';
import 'job_question_card.dart';
import 'run_again.dart';
import 'wisp_intro.dart';
import '../../ui/lock_notice.dart';
import '../../ui/page_notice.dart';
import 'wisp_page_loading.dart';
import '../../ui/job_running.dart';

/// Plot holes and continuity errors. The check is long (extract → walk →
/// verify), and the contradictions it confirms become questions — which
/// version is the story — asked at the top of this page while it runs and
/// after, until answered.
class ContinuityPage extends ConsumerWidget {
  const ContinuityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final project = ref.watch(projectProvider(projectId)).value;
    final hasChapters = project != null && chaptersInTree(project.chapters).isNotEmpty;
    final tooShort = tooShortForWholeBook(project);
    final report = ref.watch(continuityProvider(projectId));
    final questions = ref.watch(continuityQuestionsProvider(projectId));
    final runKey = continuityRunKey(projectId);
    final run = ref.watch(wispRunProvider(runKey));
    final gate = ref.watch(capabilityProvider(continuityCapability));
    final quota = quotaLine(ref.watch(quotaProvider).value?.feature(continuityQuotaFeature));

    void start({required bool force}) {
      if (!gate.granted) return explainLock(context, gate, 'Continuity check');
      ref.read(wispRunProvider(runKey).notifier).start({if (force) 'force': true});
    }

    final Widget body;
    if (project != null && !hasChapters) {
      body = const PageNotice('The manuscript has no chapters yet. Add some in Apparition and come back to Wisp.');
    } else if (run.running) {
      body = JobRunning(
        progress: run.progress,
        starting: 'Starting the check',
        note: 'Extract → walk → verify. Confirmed contradictions become questions above, while the run keeps going. You can leave this page — the result is kept.',
      );
    } else if (report.hasError && !report.hasValue) {
      body = PageNotice("The saved report wouldn't load: ${messageFor(report.error)}", error: true);
    } else if (!report.hasValue) {
      body = const WispPageLoading('Checking for a saved report…');
    } else if (report.value case final r?) {
      body = Column(
        children: [
          if (r.extractionFailures.isNotEmpty)
            PageNotice(
              'Extraction failed for ${r.extractionFailures.join(', ')} — these chapters were not checked. Re-run to try again.',
            ),
          ContinuityReportView(report: r),
          RunAgain(
            label: 'Re-run',
            onRun: () => start(force: true),
            locked: !gate.granted,
            disabled: tooShort,
            quota: quota,
          ),
        ],
      );
    } else {
      body = WispIntro(
        icon: LucideIcons.scanSearch,
        blurb: 'Identify plot holes and continuity errors.',
        action: 'Run continuity check',
        onRun: () => start(force: false),
        locked: !gate.granted,
        disabled: project == null || tooShort,
        quota: quota,
        footnote: tooShort ? wholeBookTooShort : null,
      );
    }

    return RefreshIndicator(
      color: Ds.accent,
      backgroundColor: Ds.panel,
      onRefresh: () {
        ref.invalidate(wispJobsProvider(projectId));
        return ref.refresh(continuityProvider(projectId).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: [
          if (run.error case final error? when !run.running) PageNotice(error, error: true),
          for (final open in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: JobQuestionCard(projectId: projectId, jobId: open.jobId, question: open.question),
            ),
          body,
        ],
      ),
    );
  }
}
