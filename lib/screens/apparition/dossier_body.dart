import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';

/// A written dossier, as the sheet reads it: the glance grid, the overview,
/// what the entity looks like, its sections, its ties, and the
/// chapter-by-chapter timeline — in that order, widest answer first.
///
/// Nothing here switches on a label or a section title. Both are
/// model-chosen to fit the entity (a character is asked what it Wants, a
/// place what it Runs on), so a client that recognised particular ones would
/// be re-imposing the fixed field list the pipeline deliberately doesn't have.
class DossierBody extends StatelessWidget {
  const DossierBody({super.key, required this.dossier});
  final Dossier dossier;

  @override
  Widget build(BuildContext context) {
    final chapters = dossier.chaptersUsed.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dossier.glance.isNotEmpty) ...[
          _GlanceGrid(cells: dossier.glance),
          const SizedBox(height: 22),
        ],
        if (dossier.overview.isNotEmpty) ...[
          Text(dossier.overview, style: DsStyle.prose(DsText.prose, color: Ds.ink)),
          const SizedBox(height: 22),
        ],
        if (dossier.appearance.isNotEmpty) ...[
          _Band(title: 'Appearance', child: _Prose(dossier.appearance)),
          const SizedBox(height: 22),
        ],
        for (final section in dossier.sections) ...[
          _Band(title: section.title, child: _Prose(section.body)),
          const SizedBox(height: 22),
        ],
        if (dossier.ties.isNotEmpty) ...[
          _Band(
            title: 'Ties',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final tie in dossier.ties)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Ds.edge),
                      borderRadius: BorderRadius.circular(DsGeom.radius),
                      color: Ds.surf,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tie.name, style: DsStyle.ui(DsText.ui, color: Ds.hi, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(tie.relation, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (dossier.timeline.isNotEmpty) ...[
          _Band(
            title: 'Chapter by chapter',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in dossier.timeline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.chapter.replaceAll(RegExp(r'\.md$', caseSensitive: false), ''),
                          style: DsStyle.ui(DsText.ui, color: Ds.faint),
                        ),
                        for (final event in entry.events)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(event, style: DsStyle.ui(DsText.body, color: Ds.soft)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Where it came from, so the author can tell a thin dossier from a
        // thorough one without reading it twice.
        Text(
          'Written from $chapters ${chapters == 1 ? 'chapter' : 'chapters'} of mentions'
          '${dossier.truncated ? ' · some passages trimmed to fit' : ''}',
          style: DsStyle.ui(DsText.eyebrow, color: Ds.faint),
        ),
      ],
    );
  }
}

/// The eyebrow every band in the dossier is titled with.
class _Band extends StatelessWidget {
  const _Band({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(), style: DsStyle.eyebrow()),
          const SizedBox(height: 8),
          child,
        ],
      );
}

/// Model-written prose, one paragraph per blank line.
class _Prose extends StatelessWidget {
  const _Prose(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split(RegExp(r'\n{2,}')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < paragraphs.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Text(
              paragraphs[i],
              style: DsStyle.prose(DsText.body, color: Ds.soft).copyWith(height: 23 / DsText.body.size),
            ),
          ),
      ],
    );
  }
}

class _GlanceGrid extends StatelessWidget {
  const _GlanceGrid({required this.cells});
  final List<DossierGlanceItem> cells;

  @override
  Widget build(BuildContext context) {
    // Two columns on a hairline grid; an odd last cell spans the row rather
    // than leaving a hole showing the grid's own hairline as a block. A
    // character's GMC is sentences rather than phrases, so it stacks instead.
    final rows = <Widget>[];
    if (isGmcGlance(cells)) {
      for (final (i, cell) in cells.indexed) {
        rows.add(_GlanceCell(cell, gmc: true));
        if (i + 1 < cells.length) rows.add(const SizedBox(height: 1));
      }
      return _glanceFrame(rows);
    }
    for (var i = 0; i < cells.length; i += 2) {
      final left = cells[i];
      final right = i + 1 < cells.length ? cells[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _GlanceCell(left)),
            if (right != null) ...[const SizedBox(width: 1), Expanded(child: _GlanceCell(right))],
          ],
        ),
      ));
      if (i + 2 < cells.length) rows.add(const SizedBox(height: 1));
    }
    return _glanceFrame(rows);
  }

  Widget _glanceFrame(List<Widget> rows) => ClipRRect(
        borderRadius: BorderRadius.circular(DsGeom.radius),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
            color: Ds.edge,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
        ),
      );
}

class _GlanceCell extends StatelessWidget {
  const _GlanceCell(this.cell, {this.gmc = false});
  final DossierGlanceItem cell;
  /// A GMC cell names its question in words rather than as an eyebrow, and
  /// carries what that question asks underneath it.
  final bool gmc;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: Ds.surf,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gmc) ...[
              Text(cell.label, style: DsStyle.prose(DsText.body, color: Ds.accent200)),
              if (glanceGmcMeaning[cell.label] != null)
                Text(glanceGmcMeaning[cell.label]!,
                    style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
              const SizedBox(height: 6),
              Text(cell.value, style: DsStyle.prose(DsText.body, color: Ds.ink)),
            ] else ...[
              Text(cell.label.toUpperCase(), style: DsStyle.eyebrow()),
              const SizedBox(height: 4),
              Text(cell.value, style: DsStyle.ui(DsText.body, color: Ds.hi)),
            ],
          ],
        ),
      );
}
