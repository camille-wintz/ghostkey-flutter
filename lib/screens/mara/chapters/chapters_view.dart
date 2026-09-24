import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mara/chapter_plan.dart';
import '../../../mara/proposal.dart';
import '../../../mara/providers.dart';
import '../../../poltergeist/providers.dart';
import '../../../server/dto/plan.dart';
import '../../../server/errors.dart';
import '../../../server/providers.dart';
import '../../../ui/state_screen.dart';
import 'book_list.dart';
import 'changeset_view.dart';
import 'chapters_empty.dart';
import 'proposal_view.dart';

/// The chapters of the plan, wherever it is mounted — its own page, or a
/// chat's review. The row decides first (a changeset over the book, or a
/// proposal to commit), the book once the row is spent.
class ChaptersView extends ConsumerStatefulWidget {
  const ChaptersView({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ChaptersView> createState() => _ChaptersViewState();
}

class _ChaptersViewState extends ConsumerState<ChaptersView> {
  bool _accepting = false;

  String get _projectId => widget.projectId;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authoredOutlineProvider(_projectId),
      (_, next) => Future.microtask(() {
        if (mounted) _acceptMatches(next.value);
      }),
      fireImmediately: true,
    );
  }

  /// A card left in the list is written against the chapter it names, so a
  /// match is its own acceptance; a row that says otherwise is brought into
  /// line once, as the desk does.
  void _acceptMatches(AuthoredOutline? outline) {
    if (_accepting || outline == null || !hasUnacceptedMatches(outline.chapters)) return;
    _accepting = true;
    ref
        .read(chapterPlanWritesProvider(_projectId).notifier)
        .edit(acceptMatches)
        .whenComplete(() => _accepting = false);
  }

  @override
  Widget build(BuildContext context) {
    // The plan's owner stays open while the chapters are: the book's notes
    // and targets are written through it, and so are the rows a commit owes.
    ref.watch(planBoardProvider(_projectId));
    ref.watch(chapterPlanWritesProvider(_projectId).select((s) => s.saving));

    final outline = ref.watch(authoredOutlineProvider(_projectId));
    final project = ref.watch(projectProvider(_projectId));
    final error = outline.hasError && !outline.hasValue ? outline.error : (project.hasError && !project.hasValue ? project.error : null);
    if (error != null) {
      return StateScreen(
        message: "Couldn't read the plan",
        detail: messageFor(error),
        actionLabel: 'Try again',
        onAction: () {
          ref.invalidate(authoredOutlineProvider(_projectId));
          ref.invalidate(projectProvider(_projectId));
        },
      );
    }
    final row = outline.value;
    final book = project.value;
    if (row == null || book == null) return const StateScreen(spinner: true, message: 'Reading the chapters…');

    return switch (chaptersMode(row, book.chapters)) {
      ChaptersMode.changeset => ChangesetView(projectId: _projectId, outline: row, project: book),
      ChaptersMode.proposal => ProposalView(projectId: _projectId, outline: row, project: book),
      ChaptersMode.book => BookList(projectId: _projectId, tree: book.chapters),
      ChaptersMode.empty => const ChaptersEmpty(),
    };
  }
}
