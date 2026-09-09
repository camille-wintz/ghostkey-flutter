import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import 'veil_section.dart';

/// The author's own notes on this entity — never model-authored. Read-only
/// here until the per-entity write routes exist; hidden when empty, since an
/// empty box that cannot be typed in is a promise the page can't keep.
class EntityNotes extends StatelessWidget {
  const EntityNotes({super.key, required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) => VeilSection(
        title: 'Notes',
        child: Text(notes.trim(), style: DsStyle.prose(DsText.body, color: Ds.ink)),
      );
}
