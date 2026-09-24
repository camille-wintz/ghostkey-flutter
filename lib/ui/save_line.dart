import 'package:flutter/material.dart';

import '../autosave/field_autosave.dart';
import '../ds/tokens.dart';
import 'text.dart';

/// What the fields on a page have done with the author's typing: nothing to
/// say once it has landed, "Saving…" while it goes, and why when it did not.
/// [note] says something else instead — why the fields are held still.
class SaveLine extends StatelessWidget {
  const SaveLine({super.key, required this.saves, this.note, this.padding = EdgeInsets.zero});
  final List<FieldAutosave> saves;
  final String? note;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge(saves),
        builder: (context, _) {
          final failed = saves.where((s) => s.status == FieldSaveStatus.failed).firstOrNull;
          final busy = saves.any((s) => s.status == FieldSaveStatus.dirty || s.status == FieldSaveStatus.saving);
          final line = note ?? (failed != null ? 'Not saved. ${failed.error ?? ''}' : (busy ? 'Saving…' : null));
          if (line == null) return const SizedBox.shrink();
          return Padding(
            padding: padding,
            child: UiText(line, step: DsText.ui, color: note == null && failed != null ? Ds.destructive : Ds.low),
          );
        },
      );
}
