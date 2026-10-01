import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../chat/quota_feature.dart';
import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/dto/wisp.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../wisp/access.dart';
import '../../wisp/continuity_answer.dart';
import '../../wisp/pages.dart';
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

/// Find plot holes: plot holes and continuity errors. The check is long (extract → walk →
/// verify), and the contradictions it confirms become questions — which
/// version is the story — asked at the top of this page while it runs. Once
/// the report is written each waiting question also sits on its finding, and
/// that is where it is asked then: the report keeps it answerable after its
/// job panel card is closed (closing sticks until the next run).
///
/// Below `wisp.full_reports` the report reads as a preview of one finding
/// and is made once: "Run again" is locked there, as on the analyses (the
/// server refuses a forced run with `plan_insufficient`).
class ContinuityPage extends ConsumerWidget {
  const ContinuityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final project = ref.watch(projectProvider(projectId)).value;
    final hasChapters = project != null && chaptersInTree(project.chapters).isNotEmpty;
    final tooShort = tooShortForWholeBook(project);
    final read = ref.watch(continuityProvider(projectId));
    final feed = ref.watch(continuityQuestionsProvider(projectId));
    final runKey = continuityRunKey(projectId);
    final run = ref.watch(wispRunProvider(runKey));
    final gate = ref.watch(capabilityProvider(continuityCapability));
    final fullGate = ref.watch(capabilityProvider(fullReportsCapability));
    final quota = quotaLine(ref.watch(quotaProvider).value?.lineFor(continuityQuotaFeature));

    ref.listen(wispRunProvider(runKey), (prev, next) {
      if (next.denial case final denial? when prev?.denial == null) {
        ref.invalidate(accessProvider);
        explainDenial(context, denial, fullReportsLabel);
      }
    });

    void start({required bool force}) {
      if (!gate.granted) return explainLock(context, gate, WispPage.continuity.label);
      if (force && !fullGate.granted) return explainLock(context, fullGate, fullReportsLabel);
      ref.read(wispRunProvider(runKey).notifier).start({if (force) 'force': true});
    }

    // A question the shown report carries on a finding is asked there, not
    // twice. During a run the report is not shown, so the feed asks them all.
    final onReport = run.running
        ? const <String>{}
        : {
            for (final f in read.value?.report?.hardErrors ?? const <ContinuityFinding>[])
              if (f.question case final q? when f.resolution == null) q.id,
          };
    final questions = [for (final open in feed) if (!onReport.contains(open.question.id)) open];

    final Widget body;
    if (project != null && !hasChapters) {
      body = const PageNotice('The manuscript has no chapters yet. Add some in Apparition and come back to Wisp.');
    } else if (run.running) {
      body = JobRunning(
        progress: run.progress,
        starting: 'Starting the check',
        note: 'Extract → walk → verify. Confirmed contradictions become questions above, while the run keeps going. You can leave this page — the result is kept.',
      );
    } else if (read.hasError && !read.hasValue) {
      body = PageNotice("The saved report wouldn't load: ${messageFor(read.error)}", error: true);
    } else if (!read.hasValue) {
      body = const WispPageLoading('Checking for a saved report…');
    } else if (read.value?.report case final r?) {
      body = Column(
        children: [
          if (r.extractionFailures.isNotEmpty)
            PageNotice(
              'Extraction failed for ${r.extractionFailures.join(', ')} — these chapters were not checked. Re-run to try again.',
            ),
          ContinuityReportView(
            report: r,
            preview: read.value?.preview,
            onAnswer: (question, option, text) => answerReportQuestion(ref, projectId, question, option, text),
          ),
          RunAgain(
            label: 'Re-run',
            onRun: () => start(force: true),
            locked: !gate.granted || !fullGate.granted,
            disabled: tooShort,
            quota: quota,
            note: continuityCostNote,
          ),
        ],
      );
    } else {
      body = WispIntro(
        icon: LucideIcons.scanSearch,
        blurb: 'Identify plot holes and continuity errors.',
        action: 'Find plot holes',
        onRun: () => start(force: false),
        locked: !gate.granted,
        disabled: project == null || tooShort,
        quota: quota,
        footnote: tooShort ? wholeBookTooShort : continuityCostNote,
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
          if (run.error case final error? when !run.running && run.denial == null) PageNotice(error, error: true),
          for (final open in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: JobQuestionCard(
                key: ValueKey(open.question.id),
                question: open.question,
                onAnswer: (option, text) => answerFeedQuestion(ref, projectId, open, option, text),
              ),
            ),
          body,
        ],
      ),
    );
  }
}
