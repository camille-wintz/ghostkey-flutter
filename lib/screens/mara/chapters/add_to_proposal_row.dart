import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/add_link.dart';

/// The foot of a proposal: a chapter, or a part to put chapters in.
class AddToProposalRow extends StatelessWidget {
  const AddToProposalRow({super.key, required this.onAddChapter, required this.onAddPart, this.enabled = true});
  final VoidCallback onAddChapter;
  final VoidCallback onAddPart;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Wrap(
          spacing: 22,
          runSpacing: 12,
          children: [
            AddLink(icon: LucideIcons.plus, label: 'Add a chapter', onPressed: enabled ? onAddChapter : null),
            AddLink(icon: LucideIcons.folderPlus, label: 'Add a part', onPressed: enabled ? onAddPart : null),
          ],
        ),
      );
}
