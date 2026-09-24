import 'package:flutter/material.dart';

import '../../../autosave/field_autosave.dart';
import '../../../ds/tokens.dart';
import '../../../ui/save_line.dart';

/// The author's outline, a full page of prose saving as it is typed. Whoever
/// mounts it owns the save and says when it is held still, and why.
class OutlineEditor extends StatelessWidget {
  const OutlineEditor({super.key, required this.autosave, this.readOnly = false, this.readOnlyNote});
  final FieldAutosave autosave;
  final bool readOnly;

  /// Why it is read-only, said where the save line goes.
  final String? readOnlyNote;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: TextField(
              controller: autosave.text,
              readOnly: readOnly,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: Ds.accent,
              style: DsStyle.ui(DsText.body, color: readOnly ? Ds.mid : Ds.ink).copyWith(height: 1.6),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                hintText: 'Write the outline — the story as you plan it.',
                hintStyle: DsStyle.ui(DsText.body, color: Ds.faint),
              ),
            ),
          ),
          SaveLine(
            saves: [autosave],
            note: readOnly ? readOnlyNote : null,
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          ),
        ],
      );
}
