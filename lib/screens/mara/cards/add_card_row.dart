import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/add_link.dart';

/// The foot of a board's list: a card, or a label, at the end.
class AddCardRow extends StatelessWidget {
  const AddCardRow({super.key, required this.onAddCard, required this.onAddLabel, this.enabled = true});
  final VoidCallback onAddCard;
  final VoidCallback onAddLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 20, top: 18),
        child: Wrap(
          spacing: 22,
          runSpacing: 12,
          children: [
            AddLink(icon: LucideIcons.plus, label: 'Add card', onPressed: enabled ? onAddCard : null),
            AddLink(icon: LucideIcons.heading, label: 'Add label', onPressed: enabled ? onAddLabel : null),
          ],
        ),
      );
}
