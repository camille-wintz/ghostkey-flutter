import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';
import 'veil_section.dart';

/// A character's GMC as the page shows it while reading — the desk's
/// `BibleGlanceView` in a phone's width: the answers alone, a question with
/// nothing on either side left out rather than drawn as empty boxes. The
/// dossier's answer where the author has written none is set dimmer and in
/// italic; edit mode writes them on `GmcEditorScreen`.
class EntityGmcView extends StatelessWidget {
  const EntityGmcView({super.key, required this.entity, required this.glance});

  final BibleEntity entity;
  final List<DossierGlanceItem> glance;

  /// Whether any question has an answer to show; nothing is drawn otherwise.
  static bool hasContent(BibleEntity entity, List<DossierGlanceItem> glance) =>
      _rows(entity, glance).isNotEmpty;

  static List<(String, List<(String, String, bool)>)> _rows(BibleEntity entity, List<DossierGlanceItem> glance) {
    final suggested = {for (final cell in glance) cell.label: cell.value.trim()};
    return [
      for (final question in glanceGmcQuestions)
        (
          question,
          [
            for (final side in glanceGmcSides)
              if (_answer(entity, suggested, gmcLabel(side, question)) case (final text, final dim) when text.isNotEmpty)
                (side, text, dim),
          ],
        ),
    ].where((row) => row.$2.isNotEmpty).toList();
  }

  /// The author's answer, else the dossier's — and whether it is the dossier's.
  static (String, bool) _answer(BibleEntity entity, Map<String, String> suggested, String label) {
    final own = (entity.gmc[label] ?? '').trim();
    return own.isNotEmpty ? (own, false) : (suggested[label] ?? '', true);
  }

  @override
  Widget build(BuildContext context) => VeilSection(
        title: 'Goal, motivation, conflict',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (question, sides)) in _rows(entity, glance).indexed) ...[
              if (i > 0) const SizedBox(height: 18),
              Text(question, style: DsStyle.prose(DsText.body, color: Ds.accent200)),
              for (final (side, text, dim) in sides) ...[
                const SizedBox(height: 8),
                Eyebrow(side, semibold: false),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: DsStyle.prose(DsText.body, color: dim ? Ds.low : Ds.ink)
                      .copyWith(fontStyle: dim ? FontStyle.italic : null),
                ),
              ],
            ],
          ],
        ),
      );
}
