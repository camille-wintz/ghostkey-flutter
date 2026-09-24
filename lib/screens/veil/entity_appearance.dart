import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../server/dto/bible.dart';
import 'veil_section.dart';
import 'veil_section_link.dart';
import 'veil_writable.dart';

/// What this entity looks like, in the author's words. When they have
/// written none, the dossier's appearance stands in, drawn fainter and
/// labelled as a suggestion: Keep makes it theirs, and editing starts from
/// it — the desk pre-fills its box the same way.
class EntityAppearance extends StatelessWidget {
  const EntityAppearance({
    super.key,
    required this.entity,
    required this.dossier,
    required this.onEdit,
    required this.onKeep,
  });

  final BibleEntity entity;
  final Dossier? dossier;
  final VoidCallback onEdit;

  /// Adopt the dossier's appearance as the author's.
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final own = entity.description.trim();
    final suggestion = dossier?.appearance.trim() ?? '';
    final suggested = own.isEmpty && suggestion.isNotEmpty;
    return VeilSection(
      title: 'Physical description',
      trailing: suggested ? VeilSectionLink(icon: LucideIcons.sparkles, label: "Keep the dossier's", onTap: onKeep) : null,
      child: VeilWritable(
        text: suggested ? suggestion : own,
        suggested: suggested,
        placeholder: 'How they look, in your words.',
        onTap: onEdit,
        semanticLabel: 'Edit the physical description',
      ),
    );
  }
}
