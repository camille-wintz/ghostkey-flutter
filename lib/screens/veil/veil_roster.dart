import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/field.dart';
import '../../veil/providers.dart';
import '../../veil/roster.dart';
import 'entity_screen.dart';
import 'veil_book_tabs.dart';
import 'veil_entity_row.dart';
import 'veil_generate_callout.dart';
import 'veil_group_header.dart';
import 'veil_hidden_pile.dart';
import 'veil_stats_line.dart';
import 'veil_type_tabs.dart';

/// The roster: a search, the type and book tabs, every matching entity
/// grouped by type, the hidden pile, and the count. The list is built, not
/// laid out — one row per item, so a 400-card bible costs what is on screen.
class VeilRoster extends ConsumerStatefulWidget {
  const VeilRoster({
    super.key,
    required this.projectId,
    required this.bible,
    required this.hasChapters,
    required this.running,
    required this.onGenerate,
  });

  final String projectId;
  final BibleResponse bible;
  final bool hasChapters;
  final bool running;
  final VoidCallback onGenerate;

  @override
  ConsumerState<VeilRoster> createState() => _VeilRosterState();
}

class _VeilRosterState extends ConsumerState<VeilRoster> {
  final _query = TextEditingController();
  BibleEntityType? _type;
  String? _book;
  bool _hiddenOpen = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _open(BibleEntity entity) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EntityScreen(entityKey: entity.key)));
  }

  @override
  Widget build(BuildContext context) {
    final entities = widget.bible.entities;
    if (entities.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          VeilGenerateCallout(hasChapters: widget.hasChapters, running: widget.running, onGenerate: widget.onGenerate),
        ],
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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: GkField(
            controller: _query,
            placeholder: 'Search names and aliases…',
            autocorrect: false,
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
        if (view.groups.isEmpty) _EmptyRow(_emptyMessage(view)),
        if (view.hidden.isNotEmpty) const _HiddenRow(),
        _FooterRow(
          view.shown == view.total
              ? '${view.total} ${view.total == 1 ? 'entity' : 'entities'}'
              : '${view.shown} of ${view.total} shown',
        ),
      ];

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
            count: entity.mentionsIn(_book),
            peak: view.peak,
            elsewhere: _book == null && appearsElsewhere(entity, widget.projectId),
            summary: dossierSummary(dossiers[entity.key]),
            onOpen: () => _open(entity),
          ),
        _EmptyRow(:final message) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Text(message, textAlign: TextAlign.center, style: DsStyle.ui(DsText.body, color: Ds.low)),
          ),
        _HiddenRow() => VeilHiddenPile(
            entities: view.hidden,
            open: _hiddenOpen,
            onToggle: () => setState(() => _hiddenOpen = !_hiddenOpen),
          ),
        _FooterRow(:final text) => Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
            child: Text(text, style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
          ),
      };
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
  const _EmptyRow(this.message);
  final String message;
}

class _HiddenRow extends _Row {
  const _HiddenRow();
}

class _FooterRow extends _Row {
  const _FooterRow(this.text);
  final String text;
}
