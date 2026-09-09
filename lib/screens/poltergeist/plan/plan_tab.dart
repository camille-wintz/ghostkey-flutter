import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../poltergeist/manuscript.dart';
import '../../../poltergeist/plan_board.dart';
import '../../../poltergeist/plan_rules.dart';
import '../../../poltergeist/plan_tree.dart';
import '../../../poltergeist/providers.dart';
import '../../../server/dto/projects.dart';
import '../../../server/errors.dart';
import '../../../server/projects/api.dart';
import '../../../server/providers.dart';
import '../../../ui/notice_modal.dart';
import '../../../ui/press.dart';
import '../project_scope_id.dart';
import 'add_chapter_sheet.dart';
import 'plan_action_sheet.dart';
import 'plan_board_header.dart';
import 'plan_board_status.dart';
import 'plan_chapter_row.dart';
import 'plan_folder_header.dart';
import 'plan_row_frame.dart';

/// The board: what each chapter owes, laid out by the manuscript's own tree.
/// Seeds itself on a first open, holds itself against the manuscript on
/// every open, and writes the whole plan back on each change.
class PlanTab extends ConsumerStatefulWidget {
  const PlanTab({super.key});

  @override
  ConsumerState<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends ConsumerState<PlanTab> {
  final Set<String> _collapsed = {};
  String? _expandedId;
  bool _adding = false;

  Future<void> _openPill(String projectId, PlanChapter chapter) async {
    final choice = await showPlanActionSheet(context, chapter);
    if (choice == null || !mounted) return;
    final notifier = ref.read(planBoardProvider(projectId).notifier);
    switch (choice) {
      case AssignChoice(:final kind):
        notifier.act(chapter.id, PlanOp.assign, kind: kind);
      case ClearChoice():
        notifier.act(chapter.id, PlanOp.clear);
      case ConfirmChoice():
        notifier.act(chapter.id, PlanOp.confirm);
      case ToggleDoneChoice():
        notifier.act(chapter.id, chapter.done ? PlanOp.undone : PlanOp.done);
    }
  }

  Future<void> _remove(String projectId, PlanChapter chapter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove “${chapter.label}”?'),
        content: const Text('The chapter is already gone from the manuscript — this clears its row from the board.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Remove', style: TextStyle(color: Ds.destructive)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) ref.read(planBoardProvider(projectId).notifier).removeRow(chapter.id);
  }

  /// The board's "+": a real (empty) chapter at the end of the manuscript.
  /// The reconcile that follows the project refetch mints its row, owing the
  /// write.
  Future<void> _addChapter(String projectId) async {
    final title = await showAddChapterSheet(context);
    if (title == null || !mounted) return;
    setState(() => _adding = true);
    try {
      await createDocument(projectId, kind: DocumentKind.chapter, filename: chapterFilename(title));
      ref.invalidate(projectProvider(projectId));
    } catch (e) {
      if (!mounted) return;
      await showNoticeModal(
        context,
        eyebrow: 'Plan',
        title: "The chapter didn't start",
        action: 'OK',
        children: [NoticeText(messageFor(e))],
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectId = projectIdOf(context);
    final board = ref.watch(planBoardProvider(projectId));
    final project = ref.watch(projectProvider(projectId)).value;
    final words = ref.watch(projectWordCountProvider(projectId)).value;
    final state = board.value;

    if (state == null) {
      final error = board.error;
      if (error != null) {
        return switch (error) {
          PlanSeedFailed() => PlanBoardStatus(
              message: "The board couldn't read the manuscript to build itself.",
              onRetry: () => ref.invalidate(planBoardProvider(projectId)),
            ),
          PlanFormatUnsupported() => const PlanBoardStatus(
              message: 'This plan was written by another version of Ghostkey. Open it on the desktop first.',
            ),
          _ => PlanBoardStatus(message: "The plan didn't load.", onRetry: () => ref.invalidate(planBoardProvider(projectId))),
        };
      }
      final stored = ref.watch(projectPlanProvider(projectId));
      final seeding = stored.hasValue && stored.value == null;
      return PlanBoardStatus(message: seeding ? 'Listing the chapters…' : 'Loading the plan…');
    }

    final tree = project?.chapters ?? const <ChaptersListEntry>[];
    final wordsById = {for (final d in chaptersInTree(tree)) d.id: d.wordCount};
    final entries = planTree(state.plan.chapters, tree);
    final folderNames = [for (final e in entries) if (e is PlanFolderEntry) e.name];
    final allCollapsed = folderNames.isNotEmpty && folderNames.every(_collapsed.contains);
    final items = planListItems(entries, (name) => !_collapsed.contains(name));
    // Seed and reconcile write the plan from the notifier's build — freeze
    // hand edits while one is in flight so the two writers can't race.
    final frozen = board.isLoading || _adding;
    final notifier = ref.read(planBoardProvider(projectId).notifier);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanBoardHeader(
          chapterCount: state.plan.chapters.length,
          folderCount: folderNames.length,
          words: words,
          isReconciling: board.isLoading,
          allCollapsed: allCollapsed,
          onToggleAll: () => setState(() {
            if (allCollapsed) {
              _collapsed.clear();
            } else {
              _collapsed.addAll(folderNames);
            }
          }),
          onAddChapter: () => _addChapter(projectId),
          addDisabled: frozen,
        ),
        if (state.saveError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(child: Text("The last change didn't save.", style: DsStyle.ui(DsText.ui, color: Ds.attention400))),
                Press(
                  onPressed: notifier.retrySave,
                  semanticLabel: 'Retry',
                  builder: (context, pressed) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('Retry', style: DsStyle.ui(DsText.ui, color: pressed ? Ds.attention300 : Ds.attention400, weight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'The manuscript has no chapters yet. Add the first one with the + above — it starts a real chapter, owing its write.',
              style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: 1 + items.length,
      itemBuilder: (context, i) {
        if (i == 0) return header;
        return switch (items[i - 1]) {
          PlanFolderHeaderItem(:final name, :final rows, :final open) => PlanFolderHeader(
              key: ValueKey('folder-$name'),
              name: name,
              rows: rows,
              open: open,
              onToggle: () => setState(() => _collapsed.contains(name) ? _collapsed.remove(name) : _collapsed.add(name)),
            ),
          PlanRowItem(:final row, :final inFolder, :final last) => PlanRowFrame(
              key: ValueKey(row.id),
              inFolder: inFolder,
              last: last,
              child: PlanChapterRow(
                chapter: row,
                words: row.documentId == null ? null : wordsById[row.documentId],
                expanded: _expandedId == row.id,
                frozen: frozen,
                inFolder: inFolder,
                last: last,
                onToggleExpand: () => setState(() => _expandedId = _expandedId == row.id ? null : row.id),
                onPill: () => _openPill(projectId, row),
                onNotes: (notes) => notifier.setNotes(row.id, notes),
                onConfirm: () => notifier.act(row.id, PlanOp.confirm),
                onRemove: () => _remove(projectId, row),
              ),
            ),
        };
      },
    );
  }
}
