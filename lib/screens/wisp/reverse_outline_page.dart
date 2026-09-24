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
import '../../wisp/providers.dart';
import '../../wisp/wisp_run.dart';
import '../project/project_root.dart';
import 'chapter_outline_card.dart';
import 'condensed_outline_view.dart';
import 'outline_length_tabs.dart';
import 'run_again.dart';
import 'wisp_intro.dart';
import '../../ui/lock_notice.dart';
import '../../ui/page_notice.dart';
import 'wisp_page_loading.dart';
import '../../ui/job_running.dart';

({String blurb, String action, String title}) _copyFor(OutlineLength length) => switch (length) {
      OutlineLength.synopsis => (
          blurb:
              "The whole story in 800–1,000 words, from setup to resolution — condensed from the detailed outline, which is read first if there isn't one yet.",
          action: 'Write the synopsis',
          title: 'synopsis',
        ),
      OutlineLength.extended => (
          blurb:
              'The story in 2,000–5,000 words, setup to resolution, with its subplots woven through the main line — condensed from the detailed outline.',
          action: 'Write the extended outline',
          title: 'extended outline',
        ),
      OutlineLength.detailed => (
          blurb:
              'A summary of every chapter as it is written now, each read with the whole book in view — to see the shape of what you have before you change it.',
          action: 'Outline the book',
          title: 'detailed outline',
        ),
    };

/// The manuscript read back at the length the author picks: a synopsis, an
/// extended outline, or chapter by chapter. Every length shares one job slot,
/// so while one is being written the others wait.
class ReverseOutlinePage extends ConsumerStatefulWidget {
  const ReverseOutlinePage({super.key});

  @override
  ConsumerState<ReverseOutlinePage> createState() => _ReverseOutlinePageState();
}

class _ReverseOutlinePageState extends ConsumerState<ReverseOutlinePage> {
  OutlineLength _length = OutlineLength.synopsis;

  @override
  Widget build(BuildContext context) {
    final projectId = ProjectScope.of(context);
    final project = ref.watch(projectProvider(projectId)).value;
    final hasChapters = project != null && chaptersInTree(project.chapters).isNotEmpty;
    final outline = ref.watch(outlineProvider(projectId));
    final runKey = outlineRunKey(projectId);
    final run = ref.watch(wispRunProvider(runKey));
    final gate = ref.watch(capabilityProvider(outlineCapability));
    final quota = quotaLine(ref.watch(quotaProvider).value?.feature(outlineQuotaFeature));
    final copy = _copyFor(_length);

    // A run found already going does not say which length it makes, so it
    // holds every tab.
    final runningHere = run.running && (run.tag == null || run.tag == _length);
    final runningElsewhere = run.running && !runningHere;

    void start({required bool force}) {
      if (!gate.granted) return explainLock(context, gate, 'Reverse outline');
      ref.read(wispRunProvider(runKey).notifier).start({
        if (_length != OutlineLength.detailed) 'length': _length.wire,
        if (force) 'force': true,
      }, tag: _length);
    }

    final result = outline.value;
    final condensed = result?.condensed(_length);
    final hasDetailed = result != null && result.chapters.isNotEmpty;

    final Widget body;
    if (project != null && !hasChapters) {
      body = const PageNotice('The manuscript has no chapters yet. Add some in Apparition and come back to Wisp.');
    } else if (runningHere) {
      final outlined = run.progress?.current ?? 0;
      body = JobRunning(
        progress: run.progress,
        starting: 'Outlining the manuscript',
        note: _length == OutlineLength.detailed && outlined > 0
            ? '$outlined chapter${outlined == 1 ? '' : 's'} outlined so far. You can leave this page — the result is kept.'
            : null,
      );
    } else if (outline.hasError && !outline.hasValue) {
      body = PageNotice("The saved outline wouldn't load: ${messageFor(outline.error)}", error: true);
    } else if (!outline.hasValue) {
      body = const WispPageLoading('Looking for a saved outline…');
    } else if (condensed != null || (_length == OutlineLength.detailed && hasDetailed)) {
      body = Column(
        children: [
          if (condensed != null)
            CondensedOutlineView(outline: condensed)
          else
            for (final (i, chapter) in result!.chapters.indexed)
              ChapterOutlineCard(chapter: chapter, index: i, isLast: i == result.chapters.length - 1),
          RunAgain(
            label: 'Read the book again',
            onRun: runningElsewhere ? () {} : () => start(force: true),
            locked: !gate.granted,
            quota: quota,
          ),
        ],
      );
    } else {
      body = WispIntro(
        icon: LucideIcons.listTree,
        blurb: copy.blurb,
        action: copy.action,
        onRun: () => start(force: false),
        locked: !gate.granted,
        disabled: project == null || runningElsewhere,
        quota: quota,
        footnote: runningElsewhere ? "Another length is being written — this one can start when it's done." : null,
      );
    }

    return RefreshIndicator(
      color: Ds.accent,
      backgroundColor: Ds.panel,
      onRefresh: () => ref.refresh(outlineProvider(projectId).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          OutlineLengthTabs(value: _length, onChange: (length) => setState(() => _length = length)),
          const SizedBox(height: 18),
          if (run.error case final error? when !run.running) PageNotice(error, error: true),
          body,
        ],
      ),
    );
  }
}
