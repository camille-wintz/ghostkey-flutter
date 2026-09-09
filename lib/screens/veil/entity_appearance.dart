import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import 'veil_section.dart';

/// What this entity looks like: the author's words when they have written
/// some, the dossier's when they haven't — labelled as such, because on the
/// desktop the dossier's text only pre-fills a box the author then commits.
/// Read-only here until the per-entity write routes exist.
class EntityAppearance extends StatelessWidget {
  const EntityAppearance({super.key, required this.entity, required this.dossier});
  final BibleEntity entity;
  final Dossier? dossier;

  @override
  Widget build(BuildContext context) {
    final own = entity.description.trim();
    final text = own.isNotEmpty ? own : (dossier?.appearance.trim() ?? '');
    return VeilSection(
      title: 'Physical description',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: DsStyle.prose(DsText.body, color: Ds.ink)),
          if (own.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'From the dossier — yours to keep or rewrite on the desktop.',
                style: DsStyle.ui(DsText.eyebrow, color: Ds.faint),
              ),
            ),
        ],
      ),
    );
  }
}
