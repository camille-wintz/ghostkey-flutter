import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../server/dto/projects.dart';

/// The expanded row body: the writer's notes, always editable, never
/// measured — the plan row's own notes, which is why the same paragraph is
/// on the card in Mara. The desktop also shows the reverse-outline summary
/// and the chapter's cast here; neither lives on the phone.
class PlanChapterEditor extends StatefulWidget {
  const PlanChapterEditor({super.key, required this.chapter, required this.onNotes, this.disabled = false});
  final PlanChapter chapter;
  final ValueChanged<String> onNotes;
  final bool disabled;

  @override
  State<PlanChapterEditor> createState() => _PlanChapterEditorState();
}

class _PlanChapterEditorState extends State<PlanChapterEditor> {
  late final TextEditingController _controller = TextEditingController(text: widget.chapter.notes);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(26, 4, 0, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NOTES', style: DsStyle.eyebrow()),
            TextField(
              controller: _controller,
              enabled: !widget.disabled,
              maxLines: null,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: Ds.accent,
              onChanged: widget.onNotes,
              style: DsStyle.ui(DsText.ui, color: widget.disabled ? Ds.low : Ds.soft).copyWith(height: 1.6),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                hintText: widget.chapter.action == PlanActionKind.write
                    ? 'What is this chapter supposed to do?'
                    : 'What should the next pass accomplish?',
                hintStyle: DsStyle.ui(DsText.ui, color: Ds.faint),
              ),
            ),
          ],
        ),
      );
}
