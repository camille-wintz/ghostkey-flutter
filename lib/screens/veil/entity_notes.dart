import 'package:flutter/material.dart';

import 'veil_section.dart';
import 'veil_writable.dart';

/// The author's own notes on this entity — never model-authored, and the one
/// field on the page no regeneration touches.
class EntityNotes extends StatelessWidget {
  const EntityNotes({super.key, required this.notes, required this.onEdit});
  final String notes;
  final VoidCallback onEdit;

  static const placeholder = "Anything the draft hasn't decided yet — kept across re-reads.";

  @override
  Widget build(BuildContext context) => VeilSection(
        title: 'Your notes',
        child: VeilWritable(
          text: notes,
          placeholder: placeholder,
          onTap: onEdit,
          semanticLabel: 'Edit your notes',
        ),
      );
}
