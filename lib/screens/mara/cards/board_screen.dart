import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../access/quota_refusals.dart';
import '../../../mara/access.dart';
import '../../../mara/board_edits.dart';
import '../../../mara/boards.dart';
import '../../../mara/chapter_plan.dart';
import '../../../mara/open_board.dart';
import '../../../mara/pages.dart';
import '../../../mara/providers.dart';
import '../../../mara/runs.dart';
import '../../../server/dto/plan.dart';
import '../../../server/dto/projects.dart';
import '../../../server/providers.dart';
import '../../../ui/button.dart';
import '../../../ui/confirm_sheet.dart';
import '../../../ui/job_running.dart';
import '../../../ui/name_sheet.dart';
import '../../../ui/page_footer.dart';
import '../../../ui/page_notice.dart';
import '../../../ui/progress_line.dart';
import '../../../ui/room_bar_action.dart';
import '../../../ui/room_subtitle.dart';
import '../dismiss_proposal.dart';
import '../mara_page_frame.dart';
import '../mara_page_screen.dart';
import '../plan_in_chat.dart';
import '../proposal_ledge.dart';
import 'add_card_row.dart';
import 'board_card_list.dart';
import 'board_menu.dart';
import 'card_page.dart';
import 'empty_board.dart';

/// A board, open: its cards as a list, what acts on the board in the bar,
/// and the chapters it can become at the foot. The board's name goes back to
/// the picker.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key, required this.projectId, required this.board});
  final String projectId;
  final StoryMap board;

  BoardKey get _key => (projectId: projectId, mapId: board.id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(storyTemplatesProvider).value?.where((t) => t.id == board.templateId).firstOrNull;
    final title = boardTitle(board, template?.name);
    final hints = template?.hints ?? const <String, String>{};
    final project = ref.watch(projectProvider(projectId)).value;
    final hasChapters = project != null && chaptersInTree(project.chapters).isNotEmpty;
    final outline = ref.watch(authoredOutlineProvider(projectId)).value;
    final dismissing = ref.watch(chapterPlanWritesProvider(projectId).select((s) => s.dismissing));
    final edits = ref.watch(boardEditsProvider(_key));
    final boards = ref.watch(boardsProvider(projectId));
    final run = ref.watch(boardFillRunProvider(projectId));
    final filling = run.running && (run.tag == null || run.tag == board.id);
    final cards = board.cards;
    final hasBeats = cards.any((c) => !c.isLabel && c.description.trim().isNotEmpty);
    final templateId = board.templateId;

    Future<void> openCard(String? cardId) async {
      if (cardId == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CardPage(board: _key, cardId: cardId)),
      );
    }

    Future<void> add({bool label = false}) async =>
        openCard(await ref.read(boardEditsProvider(_key).notifier).add(label: label));

    Future<void> fill() async {
      if (templateId == null) return;
      final ok = await showConfirmSheet(
        context,
        eyebrow: 'Fill from your book',
        title: 'Fill the grid from your book?',
        message: "This reads the manuscript and fills every card from what it finds. What's on the board now is not kept anywhere else.",
        confirmLabel: 'Fill the grid',
      );
      if (!ok) return;
      final snapshot = ref.read(quotaProvider).value;
      if (snapshot?.feature(boardFillQuotaFeature)?.remaining == 0) {
        return reportQuotaSpent(boardFillQuotaFeature, snapshot: snapshot);
      }
      await ref.read(boardFillRunProvider(projectId).notifier).fill(mapId: board.id, templateId: templateId);
    }

    Future<void> menu() async {
      final action = await showBoardMenu(
        context,
        title: title,
        fillOffered: templateId != null,
        fillEnabled: hasChapters && !run.running,
      );
      if (action == null || !context.mounted) return;
      switch (action) {
        case BoardAction.rename:
          final name = await showNameSheet(
            context,
            eyebrow: 'Rename board',
            current: title,
            action: 'Rename',
            placeholder: 'What you want to call it',
            maxLength: 120,
            allowEmpty: true,
          );
          if (name == null || name == title) return;
          await ref.read(boardsProvider(projectId).notifier).rename(board.id, name.isEmpty ? null : name);
        case BoardAction.fill:
          await fill();
        case BoardAction.delete:
          final ok = await showConfirmSheet(
            context,
            eyebrow: 'Delete board',
            title: 'Delete “$title”?',
            message: 'The other boards you started are kept.',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (!ok) return;
          await ref.read(boardsProvider(projectId).notifier).delete(board.id);
          ref.read(openBoardProvider(projectId).notifier).close();
      }
    }

    final errors = [?edits.error, ?boards.error, if (!run.running) ?run.error];

    return MaraPageFrame(
      title: title,
      titleLabel: 'Your boards',
      subtitle: RoomSubtitle(template?.name ?? 'Cards'),
      onTitle: (_) => ref.read(openBoardProvider(projectId).notifier).close(),
      trailing: RoomBarAction(icon: LucideIcons.ellipsis, semanticLabel: 'Board', onPressed: menu),
      child: Column(
        children: [
          if (outline != null && outline.pending)
            ProposalLedge(
              count: outline.changeset?.ops.length ?? proposalChapters(outline.chapters).length,
              changeset: outline.changeset != null,
              madeFrom: outline.brokenFrom.mapId == board.id ? 'this board' : null,
              consequence: outline.brokenFrom.mapId == board.id ? 'Editing this board lets the proposal go.' : null,
              dismissing: dismissing,
              onReview: () => openMaraPage(context, MaraPage.chapters),
              onDismiss: () => dismissProposal(context, ref, projectId, changeset: outline.changeset != null),
            ),
          if (filling) ProgressLine(jobProgressLine(run.progress, 'Reading the book')),
          if (errors.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: PageNotice(errors.first, error: true)),
          Expanded(
            child: cards.isEmpty
                ? EmptyBoard(
                    onAddCard: () => add(),
                    onFill: templateId != null && hasChapters && !run.running ? fill : null,
                  )
                : BoardCardList(
                    projectId: projectId,
                    board: board,
                    hints: hints,
                    editable: !filling,
                    footer: AddCardRow(
                      enabled: !edits.writing && !filling,
                      onAddCard: () => add(),
                      onAddLabel: () => add(label: true),
                    ),
                  ),
          ),
          PageFooter(
            child: GkButton(
              label: 'Generate chapters',
              wide: true,
              disabled: !hasBeats || filling,
              onPressed: () => planChaptersInChat(
                context,
                ref,
                projectId: projectId,
                title: 'Chapters from the cards',
                ask: 'Plan the chapters from my board “$title”.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
