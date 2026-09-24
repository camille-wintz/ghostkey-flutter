import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../autosave/field_autosave.dart';
import '../../../ds/tokens.dart';
import '../../../mara/chapter_plan.dart';
import '../../../mara/proposal.dart';
import '../../../server/dto/plan.dart';
import '../../../ui/button.dart';
import '../../../ui/save_line.dart';
import '../../../ui/text.dart';
import 'status_colors.dart';

/// A proposed chapter's fields, each saved as typed into the proposal (the
/// whole tree, as every proposal edit is), over what the book already has.
class ProposalChapterFields extends ConsumerStatefulWidget {
  const ProposalChapterFields({super.key, required this.projectId, required this.chapter});
  final String projectId;

  /// Read once as the page opens; the fields are the author's from then on.
  final ProposalChapter chapter;

  @override
  ConsumerState<ProposalChapterFields> createState() => _ProposalChapterFieldsState();
}

class _ProposalChapterFieldsState extends ConsumerState<ProposalChapterFields> {
  late final ProviderContainer _container = ProviderScope.containerOf(context, listen: false);
  late final FieldAutosave _title = _field(widget.chapter.title, (c, text) => c.copyWith(title: text));
  late final FieldAutosave _notes = _field(widget.chapter.notes, (c, text) => c.copyWith(notes: text));

  FieldAutosave _field(String initial, ProposalChapter Function(ProposalChapter, String) apply) => FieldAutosave(
        initial: initial,
        save: (text) async {
          final landed = await _container
              .read(chapterPlanWritesProvider(widget.projectId).notifier)
              .edit((entries) => patchChapter(entries, widget.chapter.id, (c) => apply(c, text)));
          if (!landed) throw StateError("The proposal didn't save");
        },
      );

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _remove() async {
    await ref.read(chapterPlanWritesProvider(widget.projectId).notifier).dropChapter(widget.chapter.id);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    final status = chapterStatus(chapter);
    final match = chapter.match;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor(status), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Eyebrow(status.label, color: Ds.mid),
            if (chapter.words case final words?) ...[
              const Spacer(),
              UiText('~${wordLabel(words)}', step: DsText.ui, color: Ds.low),
            ],
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title.text,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: Ds.accent,
          style: DsStyle.prose(DsText.title, weight: FontWeight.w600, color: Ds.hi),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: 'Untitled chapter',
            hintStyle: DsStyle.prose(DsText.title, weight: FontWeight.w600, color: Ds.faint),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _notes.text,
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
            hintText: 'Chapter notes',
            hintStyle: DsStyle.prose(DsText.body, color: Ds.faint),
          ),
        ),
        const SizedBox(height: 10),
        SaveLine(saves: [_title, _notes]),
        if (match != null) ...[
          const SizedBox(height: 22),
          Eyebrow(matchLabel(chapter)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: UiText(match.filename.replaceAll(RegExp(r'\.md$', caseSensitive: false), ''), color: Ds.soft)),
              UiText(wordLabel(match.words), step: DsText.ui, color: Ds.low),
            ],
          ),
          if (match.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: statusColor(status).withValues(alpha: 0.5), width: 2))),
              child: Text(match.reason, style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(height: 1.5)),
            ),
          ],
        ],
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.centerLeft,
          child: GkButton(label: 'Remove chapter', variant: ButtonVariant.destructive, onPressed: _remove),
        ),
        const SizedBox(height: 8),
        UiText('It can be put back from the list while you are on this page.', step: DsText.ui, color: Ds.low),
      ],
    );
  }
}
