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
import '../../../ui/button.dart';
import '../../../ui/press.dart';
import '../../../ui/room_title_bar.dart';
import '../document_resolve.dart';
import '../room_alert.dart';
import 'chapter_nav_state.dart';
import 'chapter_tile.dart';
import 'document_menu.dart';
import 'nav_items.dart';
import 'folder_tile.dart';
import '../../../ui/hold_to_drag.dart';
import 'section_header.dart';

/// The page Apparition opens on (Cleo, 2026-09-24 — it used to be a panel
/// unfolded from the open chapter's title, which read as a menu over a
/// chapter rather than the room itself): the book in the bar with its count
/// under it, search (reaches notes too), plan dots, and the chapter you were
/// last in marked. ONE scroll view over the room's home and both sections,
/// every row a fixed extent — a hundred-chapter book mounts a screenful.
///
/// It opens at the top, on the home (2026-10-02): the list used to open
/// scrolled to the last chapter, and the home's where-you-left-off card is
/// that door now. A row opens its document as a page pushed on top
/// ([onOpen]); the bar's chevron is the way out of the room.
class ChapterNav extends ConsumerStatefulWidget {
  const ChapterNav({
    super.key,
    required this.state,
    required this.rename,
    required this.onBack,
    required this.onOpen,
    this.head,
  });
  final ChapterNavState state;
  final RecentRename rename;
  final VoidCallback onBack;

  /// Open a document (a chapter or a note), by filename, as its own page.
  final ValueChanged<String> onOpen;

  /// Drawn above the Chapters header while the list isn't searched — the
  /// room's home.
  final Widget? head;

  @override
  ConsumerState<ChapterNav> createState() => _ChapterNavState();
}

class _ChapterNavState extends ConsumerState<ChapterNav> {
  final ScrollController _scroll = ScrollController();
  late final TextEditingController _search = TextEditingController(text: widget.state.query);

  /// Where the last hold lifted a row from, per group; a drop back on the
  /// same slot is the row's menu rather than a move.
  int? _liftedChapter;
  int? _liftedNote;

  String get _projectId => widget.state.projectId;

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  NavLayout _layout(ProjectFull data) {
    final state = widget.state;
    final rows = filterChapterTree(state.chaptersOf(data), state.query, state.isCollapsed);
    final notes = state.notesOf(data).where((n) => matchesQuery(n.label, state.query)).toList();
    return layoutNav(rows, notes, state.query);
  }

  void _select(String filename) => widget.onOpen(filename);

  Future<void> _guard(Future<void> Function() action, String title) async {
    try {
      await action();
    } catch (e) {
      if (mounted) unawaited(showRoomAlert(context, title: title, message: messageFor(e)));
    }
  }

  Future<void> _createChapter(ProjectFull data, {String? inFolder}) => _guard(() async {
        final filename = await widget.state.createChapter(data, inFolder: inFolder);
        if (mounted) _select(filename);
      }, 'Could not create chapter');

  Future<void> _createNote(ProjectFull data) => _guard(() async {
        final filename = await widget.state.createNote(data);
        if (mounted) _select(filename);
      }, 'Could not create note');

  Future<void> _rowMenu(ProjectFull data, DocumentSummary doc) =>
      showDocumentMenu(context, ref, state: widget.state, recent: widget.rename, data: data, doc: doc);

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(projectProvider(_projectId)).value;
    final words = ref.watch(projectWordCountProvider(_projectId)).value;
    final markers = planMarkers(ref.watch(projectPlanProvider(_projectId)).value);
    final active = ref.watch(activeProjectProvider.select((p) => p.activeChapter));

    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final project = data?.project;
        final title = project?.displayTitle ?? 'Project';
        final chapterCount = data == null ? 0 : chaptersInTree(state.chaptersOf(data)).length;
        final layout = data == null ? layoutNav(const [], const [], state.query) : _layout(data);
        // A search shows matches out of their places, so there is nowhere to drop.
        final canReorder = state.query.isEmpty && !state.pending;
        // A book with no chapters: the one thing to do is a first chapter
        // (the header's + by another name).
        final bare = data != null && chapterCount == 0 && state.query.isEmpty;

        return ColoredBox(
          color: Ds.void_,
          child: Column(
            children: [
              RoomTitleBar(
                title: title,
                onBack: widget.onBack,
                subtitle: data == null
                    ? null
                    : Text('$chapterCount ${chapterCount == 1 ? 'chapter' : 'chapters'}'
                        '${words != null ? ' · ${formatWords(words)} words' : ''}'),
              ),
              _SearchRow(controller: _search, query: state.query, onChanged: state.setQuery),
              Expanded(
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    if (widget.head case final head? when state.query.isEmpty) SliverToBoxAdapter(child: head),
                    // Each section is its own group, so its header stays pinned
                    // while its rows scroll under it and the next header takes
                    // its place — the + stays a thumb away.
                    SliverMainAxisGroup(
                      slivers: [
                        PinnedHeaderSliver(
                          child: SectionHeader(label: 'Chapters', onAdd: data == null ? null : () => _createChapter(data)),
                        ),
                        if (bare)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: GkButton(label: 'Create chapter', onPressed: () => _createChapter(data)),
                              ),
                            ),
                          )
                        else if (layout.chaptersMessage != null)
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
                              if (row is ChapterRow) _rowMenu(data, row.doc);
                            },
                            onReorderItem: (from, to) {
                              if (data == null) return;
                              _guard(() => state.moveChapter(data, layout.chapterRows, from, to), 'Could not move chapter');
                            },
                            itemBuilder: (context, i) {
                              final row = layout.chapterRows[i];
                              return switch (row) {
                                FolderRow(:final id, :final name) => FolderTile(
                                    key: ValueKey('g-$id'),
                                    name: name,
                                    open: !state.isCollapsed(id),
                                    onToggle: () => state.toggleFolder(id),
                                    onAdd: data == null ? null : () => _createChapter(data, inFolder: id),
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
                                      onLongPress: canReorder || data == null ? null : () => _rowMenu(data, doc),
                                    ),
                                  ),
                              };
                            },
                          ),
                      ],
                    ),
                    if (layout.showNotes) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: navGapHeight)),
                      SliverMainAxisGroup(
                        slivers: [
                          PinnedHeaderSliver(
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
                              _rowMenu(data, layout.notes[i]);
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
                                  onLongPress: canReorder || data == null ? null : () => _rowMenu(data, doc),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    // The page runs under the gesture bar; the last row clears it.
                    SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
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
              color: Color.lerp(Ds.void_, Ds.raise, lift),
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
        height: navMessageHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsStyle.ui(DsText.body, color: Ds.low)),
        ),
      );
}
