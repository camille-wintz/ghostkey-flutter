import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../mara/chapter_plan.dart';
import '../../../mara/proposal.dart';
import '../../../poltergeist/ids.dart';
import '../../../server/dto/plan.dart';
import '../../../server/dto/projects.dart';
import '../../../ui/confirm_sheet.dart';
import '../../../ui/hold_to_drag.dart';
import '../../../ui/menu_sheet.dart';
import '../../../ui/name_sheet.dart';
import 'add_to_proposal_row.dart';
import 'chapter_row_tile.dart';
import 'part_heading.dart';
import 'proposal_chapter_page.dart';
import 'status_colors.dart';

enum _PartAction { rename, remove }

/// The proposal as a list: parts (folding, with their menu) and chapters
/// (status, number, title, words). A chapter held for a moment lifts and
/// drops anywhere — into a part, out of one — except while a filter hides
/// some of the list or a write is on its way.
class ProposalList extends ConsumerStatefulWidget {
  const ProposalList({
    super.key,
    required this.projectId,
    required this.entries,
    required this.tree,
    required this.matchesStale,
    this.filter,
  });
  final String projectId;
  final List<ProposalEntry> entries;

  /// The book, for the chapters a card can be put back from.
  final List<ChaptersListEntry> tree;
  final bool matchesStale;

  /// The status the list is narrowed to; null shows it all.
  final ChapterStatus? filter;

  @override
  ConsumerState<ProposalList> createState() => _ProposalListState();
}

class _ProposalListState extends ConsumerState<ProposalList> {
  final Set<String> _collapsed = {};

  /// The order a drop left on screen until the proposal it was sent to comes
  /// back — the drag's own picture, never a guess at the server's answer.
  List<ProposalEntry>? _dropped;

  bool _isCollapsed(String partId) => _collapsed.contains(partId);

  ChapterPlanWrites get _writes => ref.read(chapterPlanWritesProvider(widget.projectId).notifier);

  @override
  void didUpdateWidget(ProposalList old) {
    super.didUpdateWidget(old);
    if (!identical(old.entries, widget.entries)) _dropped = null;
  }

  void _open(String chapterId) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ProposalChapterPage(projectId: widget.projectId, chapterId: chapterId)),
      );

  Future<void> _partMenu(ProposalPart part) async {
    final action = await showMenuSheet<_PartAction>(
      context,
      title: part.name,
      entries: const [
        MenuEntry(icon: LucideIcons.pencil, label: 'Rename', value: _PartAction.rename),
        MenuEntry(icon: LucideIcons.folderMinus, label: 'Remove the part', value: _PartAction.remove, destructive: true),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _PartAction.rename:
        final name = await showNameSheet(context, eyebrow: 'Rename part', current: part.name, action: 'Rename');
        if (name != null && name != part.name) await _writes.edit((e) => renamePart(e, part.id, name));
      case _PartAction.remove:
        final ok = await showConfirmSheet(
          context,
          eyebrow: 'Remove the part',
          title: 'Remove the part “${part.name}”?',
          message: 'The chapters in it stay in the proposal, in its place. Only the part goes.',
          confirmLabel: 'Remove',
          destructive: true,
        );
        if (ok) await _writes.edit((e) => removePart(e, part.id));
    }
  }

  Future<void> _addChapter(List<ProposalEntry> entries) async {
    final pool = unclaimedChapters(widget.tree, entries, matchesStale: widget.matchesStale);
    var pick = -1;
    if (pool.isNotEmpty) {
      final picked = await showMenuSheet<int>(
        context,
        title: 'Add a chapter',
        entries: [
          const MenuEntry(icon: LucideIcons.plus, label: 'New empty chapter', value: -1),
          for (final (i, doc) in pool.indexed)
            MenuEntry(icon: LucideIcons.fileText, label: 'From your manuscript: ${doc.label}', value: i),
        ],
      );
      if (picked == null) return;
      pick = picked;
    }
    final carry = proposalCarry(proposalChapters(entries));
    final chapter = pick < 0
        ? ProposalChapter.added(id: newId())
        : chapterFromManuscript(pool[pick], id: newId(), carry: carry.checked || carry.mixed);
    await _writes.edit((e) => appendChapter(e, chapter));
    if (mounted && pick < 0) _open(chapter.id);
  }

  @override
  Widget build(BuildContext context) {
    final writes = ref.watch(chapterPlanWritesProvider(widget.projectId));
    final filter = widget.filter;
    final entries = _dropped ?? widget.entries;
    final rows = proposalRows(
      entries,
      isCollapsed: _isCollapsed,
      visible: filter == null ? null : (c) => chapterStatus(c) == filter,
    );
    final canReorder = filter == null && !writes.saving;

    Widget item(int i) => switch (rows[i]) {
          ProposalPartRow(:final part, :final collapsed) => PartHeading(
              key: ValueKey('p-${part.id}'),
              name: part.name,
              collapsed: collapsed,
              onToggle: () => setState(() => collapsed ? _collapsed.remove(part.id) : _collapsed.add(part.id)),
              onMenu: () => _partMenu(part),
            ),
          ProposalChapterRow(:final chapter, :final number, :final nested) => HoldToDrag(
              key: ValueKey('c-${chapter.id}'),
              index: i,
              enabled: canReorder,
              child: ChapterRowTile(
                number: number,
                title: chapter.title,
                dot: statusColor(chapterStatus(chapter)),
                nested: nested,
                measure: switch ((chapter.match, chapter.words)) {
                  (final match?, _) => wordLabel(match.words),
                  (null, final words?) => '~${wordLabel(words)}',
                  _ => null,
                },
                onTap: () => _open(chapter.id),
              ),
            ),
        };

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 32),
      buildDefaultDragHandles: false,
      itemCount: rows.length,
      proxyDecorator: (child, _, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(Ds.void_, Ds.raise, Curves.easeOutQuart.transform(animation.value)),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: child,
        ),
      ),
      onReorderStart: (_) => unawaited(HapticFeedback.selectionClick()),
      onReorderItem: (from, to) {
        if (from == to) return;
        final next = moveProposalRow(entries, rows, from, to, _isCollapsed);
        setState(() => _dropped = next);
        _writes.edit((_) => next);
      },
      footer: AddToProposalRow(
        enabled: !writes.saving,
        onAddChapter: () => _addChapter(entries),
        onAddPart: () => _writes.edit(
          (e) => appendPart(e, ProposalPart.fresh(id: newId(), name: newPartName(e))),
        ),
      ),
      itemBuilder: (context, i) => item(i),
    );
  }
}
