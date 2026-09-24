import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';
import 'veil_section.dart';
import 'veil_section_link.dart';
import 'veil_writable.dart';

/// A character's GMC as the author writes it: one block per question, what
/// it asks under it, then the external and internal answers stacked. The
/// answers are the author's (`BibleEntity.gmc`); the dossier's fill the cells
/// they have left empty, fainter, as suggestions — the desk's
/// `BibleGmcGrid` in a phone's width. A dossier rebuild changes only those.
///
/// Always drawn for a character, dossier or not: a card made by hand has no
/// dossier, and this is where its author says what the character wants.
class EntityGmc extends StatelessWidget {
  const EntityGmc({
    super.key,
    required this.entity,
    required this.glance,
    required this.onEdit,
    required this.onKeepAll,
  });

  final BibleEntity entity;
  final List<DossierGlanceItem> glance;

  /// Open one cell's sheet: its label and what it holds now.
  final void Function(String label, String current) onEdit;

  /// Make every dossier answer showing the author's own.
  final void Function(Map<String, String> cells) onKeepAll;

  @override
  Widget build(BuildContext context) {
    final suggested = {for (final cell in glance) cell.label: cell.value.trim()};
    final unkept = {
      for (final MapEntry(:key, :value) in suggested.entries)
        if (value.isNotEmpty && (entity.gmc[key] ?? '').isEmpty) key: value,
    };

    return VeilSection(
      title: 'Goal, motivation, conflict',
      trailing: unkept.isEmpty
          ? null
          : VeilSectionLink(icon: LucideIcons.sparkles, label: "Keep the dossier's", onTap: () => onKeepAll(unkept)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, question) in glanceGmcQuestions.indexed) ...[
            if (i > 0) const SizedBox(height: 18),
            Text(question, style: DsStyle.prose(DsText.body, color: Ds.accent200)),
            Text(glanceGmcMeaning[question]!, style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
            for (final side in glanceGmcSides) ...[
              const SizedBox(height: 10),
              Eyebrow(side, semibold: false),
              const SizedBox(height: 4),
              _cell(gmcLabel(side, question), suggested),
            ],
          ],
        ],
      ),
    );
  }

  Widget _cell(String label, Map<String, String> suggested) {
    final own = (entity.gmc[label] ?? '').trim();
    final suggestion = suggested[label] ?? '';
    return VeilWritable(
      text: own.isNotEmpty ? own : suggestion,
      suggested: own.isEmpty && suggestion.isNotEmpty,
      placeholder: 'Not written yet',
      prose: false,
      onTap: () => onEdit(label, own.isNotEmpty ? own : suggestion),
      semanticLabel: 'Edit $label',
    );
  }
}
