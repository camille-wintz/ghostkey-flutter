import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mara/chapter_plan.dart';
import '../../../mara/proposal.dart';
import '../../../server/dto/plan.dart';
import '../../../server/dto/projects.dart';
import '../../../ui/page_notice.dart';
import 'commit_bar.dart';
import 'proposal_filters.dart';
import 'proposal_list.dart';

/// What the plan becomes, while it is still a proposal: the list to arrange,
/// filter and trim, and the commit that makes it chapters.
class ProposalView extends ConsumerWidget {
  const ProposalView({super.key, required this.projectId, required this.outline, required this.project});
  final String projectId;
  final AuthoredOutline outline;
  final ProjectFull project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final writes = ref.watch(chapterPlanWritesProvider(projectId));
    final notifier = ref.read(chapterPlanWritesProvider(projectId).notifier);
    final chapters = proposalChapters(outline.chapters);
    final filters = statusFilters(chapters);
    // A filter whose last chapter just went would show an empty list with no
    // chip left to click out of it.
    final active = filters.any((f) => f.status == writes.filter) ? writes.filter : null;
    final stale = outline.matchedDraftId != null && outline.matchedDraftId != project.project.activeDraftId;

    return Column(
      children: [
        ProposalFilters(
          filters: filters,
          active: active,
          onSelect: notifier.setFilter,
          dropped: writes.dropped.length,
          onRestore: notifier.restoreDropped,
        ),
        if (stale)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: PageNotice(
              "These matches were read against a different draft. They point at chapters you're no longer writing in — break the outline again to match against this one.",
            ),
          ),
        if (writes.error case final error?)
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: PageNotice(error, error: true)),
        Expanded(
          child: ProposalList(
            projectId: projectId,
            entries: outline.chapters,
            tree: project.chapters,
            matchesStale: stale,
            filter: active,
          ),
        ),
        CommitBar(
          projectId: projectId,
          entries: outline.chapters,
          bookIsEmpty: chaptersInTree(project.chapters).isEmpty,
          blocked: stale,
        ),
      ],
    );
  }
}
