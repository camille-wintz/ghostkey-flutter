import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/sheet.dart';
import '../../ui/text.dart';
import '../../veil/roster.dart';
import 'tie_card.dart';

/// Tie a card to another, in two steps in one sheet: pick the card from the
/// roster — every card not tied yet — then say how they are tied, in a line.
/// The relation may stay empty; the tie is the point. The sheet closes once
/// the write has been made — a refusal is the Ties band's to say, on the
/// page. The phone web's `AddTieSheet.tsx`.
Future<void> showAddTieSheet(
  BuildContext context, {
  required String name,
  required List<BibleEntity> candidates,
  required String? seriesId,
  required Future<void> Function(String entityId, String relation) onAdd,
}) =>
    showGkSheet<void>(
      context,
      builder: (context) => _AddTie(name: name, candidates: candidates, seriesId: seriesId, onAdd: onAdd),
    );

class _AddTie extends StatefulWidget {
  const _AddTie({required this.name, required this.candidates, required this.seriesId, required this.onAdd});

  /// The card being tied, for the header.
  final String name;
  final List<BibleEntity> candidates;
  final String? seriesId;
  final Future<void> Function(String entityId, String relation) onAdd;

  @override
  State<_AddTie> createState() => _AddTieState();
}

class _AddTieState extends State<_AddTie> {
  final _relation = TextEditingController();
  BibleEntity? _picked;
  bool _saving = false;

  @override
  void dispose() {
    _relation.dispose();
    super.dispose();
  }

  void _close() {
    if (!_saving) Navigator.of(context).pop();
  }

  Future<void> _add() async {
    final picked = _picked;
    if (picked == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onAdd(picked.id, _relation.text);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return PopScope(
      canPop: !_saving,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            eyebrow: picked != null ? 'Tie to ${titleCase(picked.name)}' : 'Add a tie',
            trailing: picked != null ? null : widget.name,
            onBack: picked != null && !_saving
                ? () => setState(() {
                      _picked = null;
                      _relation.clear();
                    })
                : null,
            onClose: _close,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: picked != null ? _relationStep(picked) : _pickStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, candidate) in widget.candidates.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: TieCard(
                entity: candidate,
                relation: candidate.type.label,
                seriesId: widget.seriesId,
                onOpen: () => setState(() => _picked = candidate),
              ),
            ),
        ],
      );

  Widget _relationStep(BibleEntity picked) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText('How is ${widget.name} tied to ${titleCase(picked.name)}?', step: DsText.ui, color: Ds.low),
          const SizedBox(height: 12),
          GkField(
            controller: _relation,
            placeholder: 'Sister, rival, old debt…',
            autofocus: true,
            enabled: !_saving,
            maxLength: 200,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 16),
          GkButton(label: 'Add tie', wide: true, busy: _saving, onPressed: _add),
        ],
      );
}
