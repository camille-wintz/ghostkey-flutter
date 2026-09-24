import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../mara/changeset_review.dart';
import '../../../server/dto/plan.dart';
import '../../../ui/button.dart';
import '../../../ui/text.dart';

/// The written chapters' fields. What is typed is held with the review's
/// answers and goes with the apply — nothing is written before.
class ChangesetChapterFields extends ConsumerStatefulWidget {
  const ChangesetChapterFields({super.key, required this.projectId, required this.op, this.index});
  final String projectId;
  final ChangesetWrite op;
  final int? index;

  @override
  ConsumerState<ChangesetChapterFields> createState() => _ChangesetChapterFieldsState();
}

class _ChangesetChapterFieldsState extends ConsumerState<ChangesetChapterFields> {
  late final List<int> _shown = widget.index != null ? [widget.index!] : List.generate(widget.op.written.length, (i) => i);
  late final Map<int, (TextEditingController, TextEditingController)> _fields = {
    for (final i in _shown)
      i: () {
        final written = ref.read(changesetReviewProvider(widget.projectId)).written(widget.op, i);
        return (TextEditingController(text: written.title), TextEditingController(text: written.notes));
      }(),
  };

  @override
  void dispose() {
    for (final (title, notes) in _fields.values) {
      title.dispose();
      notes.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final review = ref.read(changesetReviewProvider(widget.projectId).notifier);
    final skipped = ref.watch(changesetReviewProvider(widget.projectId).select((a) => a.isSkipped(widget.op.id)));
    final op = widget.op;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        if (op.reason.trim().isNotEmpty) ...[
          const Eyebrow('Why'),
          const SizedBox(height: 6),
          Text(op.reason, style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(height: 1.5)),
          const SizedBox(height: 20),
        ],
        if (skipped)
          UiText('Skipped — the chapters it names stay as they are.', color: Ds.low)
        else
          for (final i in _shown) ...[
            if (op.written.length > 1 || op.written[i].from != null)
              Eyebrow([
                op.written.length > 1 ? 'Chapter ${i + 1} of ${op.written.length}' : 'Chapter',
                if (op.written[i].from case final from?)
                  'written against ${from.filename.replaceAll(RegExp(r'\.md$', caseSensitive: false), '')}',
              ].join(' · ')),
            const SizedBox(height: 8),
            TextField(
              controller: _fields[i]!.$1,
              onChanged: (text) => review.editWritten(op.id, i, title: text),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: Ds.accent,
              style: DsStyle.prose(DsText.prose, weight: FontWeight.w600, color: Ds.hi),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Chapter title',
                hintStyle: DsStyle.prose(DsText.prose, weight: FontWeight.w600, color: Ds.faint),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fields[i]!.$2,
              onChanged: (text) => review.editWritten(op.id, i, notes: text),
              maxLines: null,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: Ds.accent,
              style: DsStyle.prose(DsText.body, color: Ds.ink).copyWith(height: 1.55),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Chapter notes',
                hintStyle: DsStyle.prose(DsText.body, color: Ds.faint),
              ),
            ),
            if (op.written[i].cast.isNotEmpty) ...[
              const SizedBox(height: 8),
              UiText(op.written[i].cast.join(' · '), step: DsText.ui, color: Ds.low),
            ],
            const SizedBox(height: 24),
          ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: GkButton(
            label: skipped ? 'Restore this change' : 'Skip this change',
            variant: ButtonVariant.outline,
            onPressed: () => review.toggleSkipped(op.id),
          ),
        ),
        const SizedBox(height: 8),
        UiText('Held until you apply the changes.', step: DsText.ui, color: Ds.low),
      ],
    );
  }
}
