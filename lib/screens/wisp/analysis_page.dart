import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../chat/quota_feature.dart';
import '../../core/dates.dart';
import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/dto/wisp.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../wisp/access.dart';
import '../../wisp/providers.dart';
import '../../wisp/wisp_run.dart';
import '../project/project_root.dart';
import 'genre_report.dart';
import 'pacing_report.dart';
import 'run_again.dart';
import 'theme_report.dart';
import 'wisp_intro.dart';
import 'wisp_lock.dart';
import 'wisp_notice.dart';
import 'wisp_page_loading.dart';
import 'wisp_running.dart';

/// The desk's words for each analysis, before its first run.
({String intro, String action, IconData icon}) _copyFor(AnalysisId analysis) => switch (analysis) {
      AnalysisId.theme => (
          intro:
              "Reads the whole book's outline and its first two and last two chapters in full, then names every theme it carries — what it says, the machinery behind it, and how it moves from the opening to the close.",
          action: 'Analyze theme',
          icon: LucideIcons.sparkles,
        ),
      AnalysisId.pacing => (
          intro:
              "Reads the whole book's outline and charts every chapter's intensity as a wave, then describes the stretches it falls into and how the rhythm serves the story.",
          action: 'Analyze pacing',
          icon: LucideIcons.activity,
        ),
      AnalysisId.genre => (
          intro:
              "Reads the whole book's outline, names the genres a reader will shelve it under, and lists each genre's expectations as met, subverted, or not addressed.",
          action: 'Analyze genre expectations',
          icon: LucideIcons.library,
        ),
    };

/// One book analysis's page, whichever analysis: the report once there is
/// one, with Run again under it; otherwise what a run does and the button.
class AnalysisPage extends ConsumerWidget {
  const AnalysisPage({super.key, required this.analysis});
  final AnalysisId analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final copy = _copyFor(analysis);
    final project = ref.watch(projectProvider(projectId)).value;
    final hasChapters = project != null && chaptersInTree(project.chapters).isNotEmpty;
    final readKey = (projectId: projectId, analysis: analysis);
    final report = ref.watch(analysisProvider(readKey));
    final runKey = analysisRunKey(projectId, analysis);
    final run = ref.watch(wispRunProvider(runKey));
    final gate = ref.watch(capabilityProvider(analysisCapability));
    final quotas = ref.watch(quotaProvider).value;
    final quota = quotaLine(quotas?.feature(analysisQuotaFeature(quotas, analysis)));

    void start() {
      if (!gate.granted) return explainWispLock(context, gate, 'Book analyses');
      ref.read(wispRunProvider(runKey).notifier).start({'analysis': analysis.wire});
    }

    final Widget body;
    if (project != null && !hasChapters) {
      body = const WispNotice('The manuscript has no chapters yet. Add some in Apparition and come back to Wisp.');
    } else if (run.running) {
      body = WispRunning(progress: run.progress, starting: 'Starting');
    } else if (report.hasError && !report.hasValue) {
      body = WispNotice("The saved analysis wouldn't load: ${messageFor(report.error)}", error: true);
    } else if (!report.hasValue) {
      body = const WispPageLoading('Looking for a saved analysis…');
    } else if (report.value case final r?) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Read ${formatShortDate(r.generatedAt)} · ${r.chapterCount} chapters',
            style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
          ),
          const SizedBox(height: 14),
          switch (analysis) {
            AnalysisId.theme => ThemeReport(report: r),
            AnalysisId.pacing => PacingReport(report: r),
            AnalysisId.genre => GenreReport(report: r),
          },
          RunAgain(label: 'Run again', onRun: start, locked: !gate.granted, quota: quota),
        ],
      );
    } else {
      body = WispIntro(
        icon: copy.icon,
        blurb: copy.intro,
        action: copy.action,
        onRun: start,
        locked: !gate.granted,
        disabled: project == null,
        quota: quota,
      );
    }

    return RefreshIndicator(
      color: Ds.accent,
      backgroundColor: Ds.panel,
      onRefresh: () => ref.refresh(analysisProvider(readKey).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: [
          if (run.error case final error? when !run.running) WispNotice(error, error: true),
          body,
        ],
      ),
    );
  }
}
