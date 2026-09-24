import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../poltergeist/providers.dart';
import '../../../server/dto/projects.dart';
import '../../../ui/text.dart';
import '../../../wisp/providers.dart';

/// A chapter's target and notes, written through the plan's owner as they
/// are typed (it coalesces them into one save per pause), over the reverse
/// outline's summary of what the chapter holds — read-only, and present once
/// Wisp's reverse outline has read the book.
class BookChapterFields extends ConsumerStatefulWidget {
  const BookChapterFields({super.key, required this.projectId, required this.doc, required this.row});
  final String projectId;
  final DocumentSummary doc;

  /// Read once as the page opens; the fields are the author's from then on.
  final PlanChapter row;

  @override
  ConsumerState<BookChapterFields> createState() => _BookChapterFieldsState();
}

class _BookChapterFieldsState extends ConsumerState<BookChapterFields> {
  late final TextEditingController _target = TextEditingController(text: widget.row.targetWords?.toString() ?? '');
  late final TextEditingController _notes = TextEditingController(text: widget.row.notes);

  @override
  void dispose() {
    _target.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _setTarget(String text) {
    final words = int.tryParse(text.trim());
    ref.read(planBoardProvider(widget.projectId).notifier).setTargetWords(widget.row.id, words != null && words > 0 ? words : null);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref
        .watch(outlineProvider(widget.projectId))
        .value
        ?.chapters
        .where((c) => c.chapter == widget.doc.filename)
        .firstOrNull
        ?.summary;
    final saveError = ref.watch(planBoardProvider(widget.projectId).select((s) => s.value?.saveError));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        const Eyebrow('Target words'),
        const SizedBox(height: 8),
        SizedBox(
          width: 160,
          child: TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            onChanged: _setTarget,
            cursorColor: Ds.accent,
            style: DsStyle.ui(DsText.body, color: Ds.hi),
            decoration: InputDecoration(
              isDense: true,
              hintText: '—',
              hintStyle: DsStyle.ui(DsText.body, color: Ds.faint),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Ds.edge)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Ds.accent)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Eyebrow('Notes'),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          onChanged: (text) => ref.read(planBoardProvider(widget.projectId).notifier).setNotes(widget.row.id, text),
          maxLines: null,
          minLines: 5,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: Ds.accent,
          style: DsStyle.prose(DsText.body, color: Ds.ink).copyWith(height: 1.55),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: 'What this chapter is for',
            hintStyle: DsStyle.prose(DsText.body, color: Ds.faint),
          ),
        ),
        if (saveError != null) ...[
          const SizedBox(height: 10),
          UiText('Not saved. $saveError', step: DsText.ui, color: Ds.destructive),
        ],
        const SizedBox(height: 28),
        const Eyebrow('What the book has'),
        const SizedBox(height: 8),
        if (summary != null && summary.trim().isNotEmpty)
          Text(summary, style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(height: 1.55))
        else
          UiText(
            "No summary yet — one appears once Wisp's reverse outline has read the book.",
            step: DsText.ui,
            color: Ds.faint,
          ),
      ],
    );
  }
}
