import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';

/// The dossier's at-a-glance grid.
///
/// A CHARACTER's is the GMC — goal, motivation, conflict, arc — and each cell
/// is a sentence or two, so those stack full width with the question under the
/// label. Anything else keeps the model's own labels and the phrase-length
/// grid they were written for: two columns, hairline-separated, an odd last
/// cell spanning the row rather than leaving a hole, since the grid's own gaps
/// are the border.
class DossierGlance extends StatelessWidget {
  const DossierGlance({super.key, required this.glance});
  final List<DossierGlanceItem> glance;

  @override
  Widget build(BuildContext context) {
    if (isGmcGlance(glance)) return _GmcList(glance: glance);

    final rows = <List<DossierGlanceItem>>[];
    for (var i = 0; i < glance.length; i += 2) {
      rows.add(glance.sublist(i, i + 2 > glance.length ? glance.length : i + 2));
    }
    return Container(
      decoration: BoxDecoration(
        color: Ds.edge,
        border: Border.all(color: Ds.edge),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (r, row) in rows.indexed)
            Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : 1),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (c, cell) in row.indexed)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: c == 0 ? 0 : 1),
                          child: _Cell(cell),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.cell);
  final DossierGlanceItem cell;

  @override
  Widget build(BuildContext context) => Container(
        color: Ds.surf,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(cell.label, semibold: false),
            const SizedBox(height: 4),
            Text(cell.value, style: DsStyle.ui(DsText.body, color: Ds.hi)),
          ],
        ),
      );
}

/// The GMC as stacked rows: the question in the margin above its answer, one
/// per hairline-separated row.
class _GmcList extends StatelessWidget {
  const _GmcList({required this.glance});
  final List<DossierGlanceItem> glance;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Ds.edge,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, cell) in glance.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 1),
                child: Container(
                  color: Ds.surf,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cell.label,
                          style: DsStyle.prose(DsText.body, color: Ds.accent200)),
                      if (glanceGmcMeaning[cell.label] != null)
                        Text(glanceGmcMeaning[cell.label]!,
                            style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
                      const SizedBox(height: 6),
                      Text(cell.value, style: DsStyle.prose(DsText.body, color: Ds.ink)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
