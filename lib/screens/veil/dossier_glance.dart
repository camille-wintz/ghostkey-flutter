import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';

/// The dossier's at-a-glance grid: up to four label/value cells the model
/// picked to fit this entity, so nothing here may assume a particular label.
/// Two columns, hairline-separated; an odd last cell spans the row rather
/// than leaving a hole, since the grid's own gaps are the border.
class DossierGlance extends StatelessWidget {
  const DossierGlance({super.key, required this.glance});
  final List<DossierGlanceItem> glance;

  @override
  Widget build(BuildContext context) {
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
