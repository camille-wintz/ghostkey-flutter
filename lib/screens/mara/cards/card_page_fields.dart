import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../autosave/field_autosave.dart';
import '../../../ds/tokens.dart';
import '../../../mara/board_edits.dart';
import '../../../server/dto/plan.dart';
import '../../../ui/save_line.dart';

/// A card's two fields, each saving itself as typed. The saves outlive the
/// page by a moment: leaving it flushes what is still pending.
class CardPageFields extends ConsumerStatefulWidget {
  const CardPageFields({super.key, required this.board, required this.card, this.hint});
  final BoardKey board;
  final StoryCard card;
  final String? hint;

  @override
  ConsumerState<CardPageFields> createState() => _CardPageFieldsState();
}

class _CardPageFieldsState extends ConsumerState<CardPageFields> {
  late final ProviderContainer _container = ProviderScope.containerOf(context, listen: false);
  late final FieldAutosave _title = FieldAutosave(
    initial: widget.card.title,
    save: (text) => saveCardText(_container, widget.board, widget.card.id, title: text),
  );
  late final FieldAutosave? _description = widget.card.isLabel
      ? null
      : FieldAutosave(
          initial: widget.card.description,
          save: (text) => saveCardText(_container, widget.board, widget.card.id, description: text),
        );

  @override
  void dispose() {
    _title.dispose();
    _description?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.card.isLabel;
    final description = _description;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        TextField(
          controller: _title.text,
          autofocus: widget.card.title.isEmpty,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: Ds.accent,
          style: DsStyle.prose(DsText.title, weight: FontWeight.w600, color: Ds.hi),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: label ? 'Name this part' : 'Name this card',
            hintStyle: DsStyle.prose(DsText.title, weight: FontWeight.w600, color: Ds.faint),
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 16),
          TextField(
            controller: description.text,
            maxLines: null,
            minLines: 6,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: Ds.accent,
            style: DsStyle.prose(DsText.prose, color: Ds.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: widget.hint ?? 'What happens here?',
              hintMaxLines: 6,
              hintStyle: DsStyle.prose(DsText.prose, color: Ds.faint),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SaveLine(saves: [_title, ?description]),
      ],
    );
  }
}
