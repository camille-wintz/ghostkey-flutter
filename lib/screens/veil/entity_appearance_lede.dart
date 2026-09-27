import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';

/// What they look like, set as the reading page's lede: the author's
/// physical description in the italic prose face. Nothing when there is none
/// — edit mode is where one is written, kept from the dossier, or drawn from
/// the portrait (the desk's `BibleAppearanceLede`).
class EntityAppearanceLede extends StatelessWidget {
  const EntityAppearanceLede({super.key, required this.entity});
  final BibleEntity entity;

  static bool hasContent(BibleEntity entity) => entity.description.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) => Text(
        entity.description.trim(),
        style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic, height: 1.55),
      );
}
