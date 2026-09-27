import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import 'veil_section.dart';
import 'veil_section_link.dart';
import 'veil_writable.dart';

/// What this entity looks like, in the author's words. When they have
/// written none, the dossier's appearance stands in, drawn fainter and
/// labelled as a suggestion: Keep makes it theirs, and editing starts from
/// it — the desk pre-fills its box the same way.
///
/// With a portrait on the card, the description can also be written from it
/// ([onDescribe]); the page asks before that replaces words of the author's.
class EntityAppearance extends StatelessWidget {
  const EntityAppearance({
    super.key,
    required this.entity,
    required this.dossier,
    required this.onEdit,
    required this.onKeep,
    this.onDescribe,
    this.describing = false,
  });

  final BibleEntity entity;
  final Dossier? dossier;
  final VoidCallback onEdit;

  /// Adopt the dossier's appearance as the author's.
  final VoidCallback onKeep;

  /// Write the description from the card's portrait; null without one.
  final VoidCallback? onDescribe;

  /// The portrait is being looked at.
  final bool describing;

  @override
  Widget build(BuildContext context) {
    final own = entity.description.trim();
    final suggestion = dossier?.appearance.trim() ?? '';
    final suggested = own.isEmpty && suggestion.isNotEmpty;
    return VeilSection(
      title: 'Physical description',
      trailing: suggested ? VeilSectionLink(icon: LucideIcons.sparkles, label: "Keep the dossier's", onTap: onKeep) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VeilWritable(
            text: suggested ? suggestion : own,
            suggested: suggested,
            placeholder: 'How they look, in your words.',
            onTap: describing ? null : onEdit,
            semanticLabel: 'Edit the physical description',
          ),
          if (onDescribe case final onDescribe?) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: describing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent)),
                        const SizedBox(width: 8),
                        Text('Looking at the portrait…', style: DsStyle.ui(DsText.ui, color: Ds.low)),
                      ],
                    )
                  : VeilSectionLink(icon: LucideIcons.scanFace, label: 'Describe from portrait', onTap: onDescribe),
            ),
          ],
        ],
      ),
    );
  }
}
