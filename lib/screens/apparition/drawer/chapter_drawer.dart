import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/chapter_search.dart';
import '../../../core/plan_markers.dart';
import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../server/dto/projects.dart';
import '../../../server/errors.dart';
import '../../../server/providers.dart';
import '../../../store/active_project.dart';
import '../../../ui/press.dart';
import '../../project/drawer_head.dart';
import '../document_resolve.dart';
import '../room_alert.dart';
import 'chapter_drawer_state.dart';
import 'chapter_tile.dart';
import 'drawer_items.dart';
import 'folder_tile.dart';
import 'hold_to_drag.dart';
import 'row_sheets.dart';
import 'section_header.dart';

/// The chapters/notes panel: the project name at its head is the way back to
/// the rooms; search (reaches notes too), plan dots, and it opens on the
/// chapter you are in. ONE scroll view over both sections, every row a fixed
/// extent — a hundred-chapter book mounts a screenful, which matters because
/// the drawer is built the moment it starts to open.
///
/// Mounted fresh on every open (Flutter's drawer holds no content while
/// closed), which is what makes the reveal a starting offset rather than a
/// jump: the list is built already positioned, from the same layout table it
/// draws by, so a row it has never mounted is landed on exactly.
class ChapterDrawer extends ConsumerStatefulWidget {
  const ChapterDrawer({super.key, required this.state, required this.rename});
  final ChapterDrawerState state;
  final RecentRename rename;

  @override
  ConsumerState<ChapterDrawer> createState() => _ChapterDrawerState();
}

class _ChapterDrawerState extends ConsumerState<ChapterDrawer> {
  late final ScrollController _scroll;
  late final TextEditingController _search = TextEditingController(text: widget.state.query);

  /// Where the last hold lifted a row from, per group; a drop back on the
  /// same slot is the row's menu rather than a move.
  int? _liftedChapter;
  int? _liftedNote;

  String get _projectId => widget.state.projectId;

  @override
  void initState() {
    super.initState();
    final data = ref.read(projectProvider(_projectId)).value;
    final active = ref.read(activeProjectProvider).activeChapter;
    final offset = data == null ? null : _layout(data).offsetOfChapter(active);
    _scroll = ScrollController(initialScrollOffset: offset == null ? 0 : revealOffset(offset));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  DrawerLayout _layout(ProjectFull data) {
    final state = widget.state;
    final rows = filterChapterTree(state.chaptersOf(data), state.query, state.isCollapsed);
    final notes = state.notesOf(data).where((n) => matchesQuery(n.label, state.query)).toList();
    return layoutDrawer(rows, notes, state.query);
  }

  void _closeDrawer() => Scaffold.of(context).closeDrawer();

  void _select(String filename) {
    ref.read(activeProjectProvider.notifier).setActiveChapter(filename);
    _closeDrawer();
  }

  // Up one level, not out: the project home is where the rooms are, and
  // closing the book is its own back from there. The editor's unsaved text
  // goes with it — its autosave flushes as the room unmounts.
  void _leaveRoom() {
    final nav = Navigator.of(context);
    _closeDrawer();
    nav.pop();
  }

  Future<void> _guard(Future<void> Function() action, String title) async {
    try {
      await action();
    } catch (e) {
      if (mounted) unawaited(showRoomAlert(context, title: title, message: messageFor(e)));
    }
  }

  Future<void> _createChapter(ProjectFull data) => _guard(() async {
        final filename = await widget.state.createChapter(data);
        if (mounted) _select(filename);
      }, 'Could not create chapter');

  Future<void> _createNote(ProjectFull data) => _guard(() async {
        final filename = await widget.state.createNote(data);
        if (mounted) _select(filename);
      }, 'Could not create note');

  Future<void> _rowMenu(ProjectFull data, DocumentSummary doc, {required bool note}) async {
    final action = await showRowMenu(context, label: doc.label);
    if (!mounted || action == null) return;
    final active = ref.read(activeProjectProvider).activeChapter;
    switch (action) {
      case RowAction.rename:
        final title = await showRenameSheet(context, current: doc.label);
        if (!mounted || title == null) return;
        await _guard(() async {
          final filename = await widget.state.rename(doc, title);
          if (doc.filename == active) {
            widget.rename.note(doc.id, filename);
            ref.read(activeProjectProvider.notifier).setActiveChapter(filename);
          }
        }, 'Rename failed');
      case RowAction.delete:
        if (!await confirmDelete(context, label: doc.label) || !mounted) return;
        await _guard(() async {
          await (note ? widget.state.deleteNote(data, doc) : widget.state.deleteChapter(data, doc));
          if (doc.filename == active) ref.read(activeProjectProvider.notifier).setActiveChapter(null);
        }, 'Could not delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(projectProvider(_projectId)).value;
    final words = ref.watch(projectWordCountProvider(_projectId)).value;
    final markers = planMarkers(ref.watch(projectPlanProvider(_projectId)).value);
    final active = ref.watch(activeProjectProvider.select((p) => p.activeChapter));
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final project = data?.project;
        final title = project?.displayTitle ?? 'Project';
        final chapterCount = data == null ? 0 : chaptersInTree(state.chaptersOf(data)).length;
        final layout = data == null ? layoutDrawer(const [], const [], state.query) : _layout(data);
        // A search shows matches out of their places, so there is nowhere to drop.
        final canReorder = state.query.isEmpty && !state.pending;

        return ColoredBox(
          color: Ds.panel,
          child: Column(
            children: [
              SizedBox(height: top),
              DrawerHead(
                title: title,
                meta: '$chapterCount ${chapterCount == 1 ? 'chapter' : 'chapters'}'
                    '${words != null ? ' · ${formatWords(words)} words' : ''}',
                onLeave: _leaveRoom,
              ),
              _SearchRow(controller: _search, query: state.query, onChanged: state.setQuery),
              Expanded(
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverToBoxAdapter(
                      child: SectionHeader(label: 'Chapters', onAdd: data == null ? null : () => _createChapter(data)),
                    ),
                    if (layout.chaptersMessage != null)
                      SliverToBoxAdapter(child: _Message(layout.chaptersMessage!))
                    else
                      SliverReorderableList(
                        itemCount: layout.chapterRows.length,
                        itemExtent: DsGeom.row,
                        proxyDecorator: _carried,
                        onReorderStart: (i) => _lift(() => _liftedChapter = i),
                        onReorderEnd: (i) {
                          if (i != _liftedChapter || data == null) return;
                          final row = layout.chapterRows[i];
                          if (row is ChapterRow) _rowMenu(data, row.doc, note: false);
                        },
                        onReorderItem: (from, to) {
                          if (data == null) return;
                          _guard(() => state.moveChapter(data, layout.chapterRows, from, to), 'Could not move chapter');
                        },
                        itemBuilder: (context, i) {
                          final row = layout.chapterRows[i];
                          return switch (row) {
                            FolderRow(:final name) => FolderTile(
                                key: ValueKey('g-$name'),
                                name: name,
                                open: !state.isCollapsed(name),
                                onToggle: () => state.toggleFolder(name),
                              ),
                            ChapterRow(:final doc, :final nested) => HoldToDrag(
                                key: ValueKey('c-${doc.id}'),
                                index: i,
                                enabled: canReorder,
                                child: ChapterTile(
                                  label: doc.label,
                                  active: doc.filename == active,
                                  nested: nested,
                                  marker: markers[doc.id],
                                  onTap: () => _select(doc.filename),
                                  onLongPress: canReorder || data == null ? null : () => _rowMenu(data, doc, note: false),
                                ),
                              ),
                          };
                        },
                      ),
                    if (layout.showNotes) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: drawerGapHeight)),
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          label: 'Notes',
                          onAdd: data == null || state.query.isNotEmpty ? null : () => _createNote(data),
                        ),
                      ),
                      SliverReorderableList(
                        itemCount: layout.notes.length,
                        itemExtent: DsGeom.row,
                        proxyDecorator: _carried,
                        onReorderStart: (i) => _lift(() => _liftedNote = i),
                        onReorderEnd: (i) {
                          if (i != _liftedNote || data == null) return;
                          _rowMenu(data, layout.notes[i], note: true);
                        },
                        onReorderItem: (from, to) {
                          if (data == null) return;
                          _guard(() => state.moveNote(data, from, to), 'Could not move note');
                        },
                        itemBuilder: (context, i) {
                          final doc = layout.notes[i];
                          return HoldToDrag(
                            key: ValueKey('n-${doc.id}'),
                            index: i,
                            enabled: canReorder,
                            child: ChapterTile(
                              label: doc.label,
                              active: doc.filename == active,
                              nested: false,
                              onTap: () => _select(doc.filename),
                              onLongPress: canReorder || data == null ? null : () => _rowMenu(data, doc, note: true),
                            ),
                          );
                        },
                      ),
                    ],
                    // The list runs to the bottom edge now that nothing sits
                    // under it, so it carries the safe area itself.
                    SliverToBoxAdapter(child: SizedBox(height: bottom + 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _lift(void Function() remember) {
    remember();
    unawaited(HapticFeedback.selectionClick());
  }

  /// The carried row: the row it lifted, raised a surface step and edged.
  ///
  /// Front-loaded against Flutter's 250ms proxy animation, which is what
  /// drives this: eased out, the raise has arrived in about 80ms, so the row
  /// looks picked up when the hold ends rather than a quarter second later —
  /// and lets go as promptly on the drop. A shadow would say it louder, and
  /// the system separates surfaces by a hairline and never by one.
  static Widget _carried(Widget child, int index, Animation<double> animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final lift = Curves.easeOutQuart.transform(animation.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Color.lerp(Ds.panel, Ds.raise, lift),
              border: Border.symmetric(horizontal: BorderSide(color: Ds.edgeHi.withValues(alpha: lift))),
            ),
            child: child,
          );
        },
      );
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.controller, required this.query, required this.onChanged});
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: DsGeom.row,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
        child: Row(
          children: [
            Icon(LucideIcons.search, size: 15, color: Ds.faint),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.search,
                cursorColor: Ds.accent,
                style: DsStyle.ui(DsText.body, color: Ds.hi),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Search chapters',
                  hintStyle: DsStyle.ui(DsText.body, color: Ds.low),
                ),
              ),
            ),
            if (query.isNotEmpty)
              Press(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                semanticLabel: 'Clear search',
                hitSlop: 10,
                builder: (context, pressed) => Icon(LucideIcons.x, size: 15, color: Ds.mid),
              ),
          ],
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: drawerMessageHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsStyle.ui(DsText.body, color: Ds.low)),
        ),
      );
}
