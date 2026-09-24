import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/press.dart';
import '../../veil/providers.dart';
import '../../veil/roster.dart';
import 'entity_screen.dart';
import 'veil_book_tabs.dart';
import 'veil_empty_state.dart';
import 'veil_entity_row.dart';
import 'veil_generate_callout.dart';
import 'veil_group_header.dart';
import 'veil_hidden_pile.dart';
import 'veil_stats_line.dart';
import 'veil_type_tabs.dart';

/// The roster: a fold-away search with the type and book tabs, every matching
/// entity grouped by type, the hidden pile, and the count. The list is built, not
/// laid out — one row per item, so a 400-card bible costs what is on screen.
class VeilRoster extends ConsumerStatefulWidget {
  const VeilRoster({
    super.key,
    required this.projectId,
    required this.bible,
    required this.hasChapters,
    required this.running,
    required this.onGenerate,
    required this.onAdd,
    required this.onUnhide,
  });

  final String projectId;
  final BibleResponse bible;
  final bool hasChapters;
  final bool running;
  final VoidCallback onGenerate;

  /// Add an entry by hand, of the type the tabs are narrowed to if they are —
  /// named after the search, when it is the search that came up empty.
  final void Function(BibleEntityType? type, [String name]) onAdd;
  final Future<void> Function(BibleEntity entity) onUnhide;

  @override
  ConsumerState<VeilRoster> createState() => _VeilRosterState();
}

class _VeilRosterState extends ConsumerState<VeilRoster> {
  final _query = TextEditingController();
  BibleEntityType? _type;
  String? _book;
  bool _hiddenOpen = false;

  /// Search and the tabs are narrowing tools, not the way around the bible —
  /// the list under them is. So they fold away and the names get the screen.
  bool _searchOpen = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Folding the search away also drops the narrowing: a short list whose
  /// reason is now hidden reads as a bible that lost entities.
  void _toggleSearch() => setState(() {
        if (_searchOpen) {
          _query.clear();
          _type = null;
          _book = null;
          FocusScope.of(context).unfocus();
        }
        _searchOpen = !_searchOpen;
      });

  void _open(BibleEntity entity) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EntityScreen(entityKey: entity.key)));
  }

  @override
  Widget build(BuildContext context) {
    final entities = widget.bible.entities;
    if (entities.isEmpty) {
      return VeilEmptyState(
        hasChapters: widget.hasChapters,
        running: widget.running,
        onGenerate: widget.onGenerate,
        onAdd: () => widget.onAdd(null),
      );
    }

    final dossiers = ref.watch(dossiersProvider(widget.projectId)).value ?? const <String, Dossier>{};
    final books = bookTabs(entities);
    final book = books.any((b) => b.id == _book) ? _book : null;
    final view = buildRoster(entities, query: _query.text, type: _type, book: book);
    final present = {for (final e in entities) if (!e.hidden) e.type};
    final rows = _rows(view, dossiers);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SearchToggle(open: _searchOpen, onTap: _toggleSearch),
          ),
        ),
        if (_searchOpen) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: GkField(
              controller: _query,
              placeholder: 'Search names and aliases…',
              autocorrect: false,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: VeilTypeTabs(value: _type, present: present, onChange: (t) => setState(() => _type = t)),
          ),
          if (books.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: VeilBookTabs(
                books: books,
                value: book,
                projectId: widget.projectId,
                onChange: (id) => setState(() => _book = id),
              ),
            ),
        ],
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 40),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: rows.length,
            itemBuilder: (context, i) => _draw(rows[i], view, dossiers),
          ),
        ),
      ],
    );
  }

  List<_Row> _rows(RosterView view, Map<String, Dossier> dossiers) => [
        if (widget.bible.hasExtraction) const _StatsRow() else const _CalloutRow(),
        for (final group in view.groups) ...[
          _HeaderRow(group.type, group.entities.length),
          for (final entity in group.entities) _EntityRow(entity),
        ],
        if (view.groups.isEmpty) _EmptyRow(_emptyMessage(view), _addable()),
        if (view.hidden.isNotEmpty) const _HiddenRow(),
        _FooterRow(
          view.shown == view.total
              ? '${view.total} ${view.total == 1 ? 'entity' : 'entities'}'
              : '${view.shown} of ${view.total} shown',
        ),
      ];

  /// A search that finds nothing is usually a name the bible doesn't have
  /// yet, so the empty list offers it — unless a hidden card already answers
  /// to it, which the hidden pile is the way back to.
  String? _addable() {
    final query = _query.text.trim();
    if (query.isEmpty || entityAnsweringTo(widget.bible.entities, query) != null) return null;
    return query;
  }

  String _emptyMessage(RosterView view) {
    final query = _query.text.trim();
    if (query.isNotEmpty) return 'Nothing matches “$query”.';
    if (_book != null) return 'Nothing from the series appears in that book yet.';
    return 'No entities yet. Generate from the manuscript, or add one on the desktop.';
  }

  Widget _draw(_Row row, RosterView view, Map<String, Dossier> dossiers) => switch (row) {
        _StatsRow() => VeilStatsLine(stats: bibleStats(widget.bible.entities, dossiers)),
        _CalloutRow() => Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: VeilGenerateCallout(
              hasChapters: widget.hasChapters,
              running: widget.running,
              onGenerate: widget.onGenerate,
            ),
          ),
        _HeaderRow(:final type, :final count) => VeilGroupHeader(type: type, count: count),
        _EntityRow(:final entity) => VeilEntityRow(
            entity: entity,
            seriesId: widget.bible.seriesId,
            onOpen: () => _open(entity),
          ),
        _EmptyRow(:final message, :final addable) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              children: [
                Text(message, textAlign: TextAlign.center, style: DsStyle.ui(DsText.body, color: Ds.low)),
                if (addable != null) ...[
                  const SizedBox(height: 16),
                  GkButton(
                    label: 'Add “$addable”',
                    leading: Icon(LucideIcons.plus, size: 16, color: Ds.accent),
                    onPressed: () => widget.onAdd(_type, addable),
                  ),
                ],
              ],
            ),
          ),
        _HiddenRow() => VeilHiddenPile(
            entities: view.hidden,
            open: _hiddenOpen,
            onToggle: () => setState(() => _hiddenOpen = !_hiddenOpen),
            onUnhide: widget.onUnhide,
          ),
        _FooterRow(:final text) => Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
            child: Text(text, style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
          ),
      };
}

/// "▸ Search" — the hinge the search and the tabs fold away behind.
class _SearchToggle extends StatelessWidget {
  const _SearchToggle({required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onTap,
        semanticLabel: open ? 'Close search' : 'Search',
        builder: (context, pressed) {
          final ink = pressed ? Ds.soft : Ds.low;
          return Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(open ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 14, color: ink),
                const SizedBox(width: 6),
                Icon(LucideIcons.search, size: 14, color: ink),
                const SizedBox(width: 6),
                Text('Search', style: DsStyle.ui(DsText.ui, color: ink)),
              ],
            ),
          );
        },
      );
}

/// One row of the built list.
sealed class _Row {
  const _Row();
}

class _StatsRow extends _Row {
  const _StatsRow();
}

class _CalloutRow extends _Row {
  const _CalloutRow();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.type, this.count);
  final BibleEntityType type;
  final int count;
}

class _EntityRow extends _Row {
  const _EntityRow(this.entity);
  final BibleEntity entity;
}

class _EmptyRow extends _Row {
  const _EmptyRow(this.message, this.addable);
  final String message;

  /// The name the empty search offers to add, if it offers one.
  final String? addable;
}

class _HiddenRow extends _Row {
  const _HiddenRow();
}

class _FooterRow extends _Row {
  const _FooterRow(this.text);
  final String text;
}
