import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../chat/review/line_edit_review.dart';
import '../../../core/locate_quote.dart';
import '../../../ds/tokens.dart';
import '../../../ui/button.dart';
import '../../../ui/press.dart';
import '../../../ui/text.dart';

/// The bottom of a line-edit review: which note, what it says, the wording
/// it offers, and the verdict — or, once every note has one, the way out.
class NotePanel extends StatelessWidget {
  const NotePanel({
    super.key,
    required this.state,
    required this.locked,
    required this.onPrevious,
    required this.onNext,
    required this.onAccept,
    required this.onReject,
    required this.onDone,
  });

  final LineEditState state;

  /// A chat turn is running and may be writing the same text.
  final bool locked;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final current = state.current;
    final note = current.note;
    final suggestion = note.suggestion?.trim() ?? '';

    return DecoratedBox(
      decoration: BoxDecoration(color: Ds.panel, border: Border(top: BorderSide(color: Ds.edgeHi))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Arrow(icon: LucideIcons.chevronLeft, label: 'Previous note', onPressed: onPrevious),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${state.index + 1} of ${state.notes.length}',
                          style: DsStyle.ui(DsText.ui, color: Ds.hi, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(_category(note.category).toUpperCase(), style: DsStyle.eyebrow()),
                      ],
                    ),
                  ),
                  _Arrow(icon: LucideIcons.chevronRight, label: 'Next note', onPressed: onNext),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.28),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText(note.note, color: Ds.soft),
                      if (suggestion.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: note.quote.trim(),
                              style: TextStyle(color: Ds.low, decoration: TextDecoration.lineThrough, decorationColor: Ds.low),
                            ),
                            TextSpan(text: '  →  ', style: TextStyle(color: Ds.faint)),
                            TextSpan(text: suggestion, style: TextStyle(color: Ds.accent300)),
                          ]),
                          style: DsStyle.ui(DsText.body),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _footer(current),
              ),
              if (state.error case final error?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: UiText(error, step: DsText.ui, color: Ds.destructive),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(ReviewedNote current) {
    if (current.verdict != NoteVerdict.pending) {
      final accepted = current.verdict == NoteVerdict.accepted;
      return Row(
        children: [
          Icon(accepted ? LucideIcons.check : LucideIcons.x, size: 16, color: accepted ? Ds.done : Ds.low),
          const SizedBox(width: 6),
          Expanded(child: UiText(accepted ? 'Accepted' : 'Rejected', step: DsText.ui, color: Ds.mid)),
          if (state.pendingCount == 0) _done(),
        ],
      );
    }

    final reason = switch (state.resolved) {
      NotApplicable(reason: Unappliable.notFound) => 'That passage has changed, so this can’t be applied.',
      NotApplicable(reason: Unappliable.noSuggestion) => 'No wording offered — a note to weigh.',
      Applicable() => null,
    };
    if (locked) return UiText('Waiting for the chat to finish its answer…', step: DsText.ui, color: Ds.low);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reason != null)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: UiText(reason, step: DsText.ui, color: Ds.low)),
        Row(
          children: [
            Expanded(
              child: GkButton(
                label: reason == null ? 'Reject' : 'Skip',
                variant: ButtonVariant.outline,
                onPressed: onReject,
                disabled: state.saving,
                wide: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GkButton(
                label: 'Accept',
                onPressed: onAccept,
                disabled: reason != null,
                busy: state.saving,
                wide: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _done() => GkButton(
        label: 'Done · ${state.acceptedCount} accepted',
        onPressed: onDone,
      );

  static String _category(String category) => switch (category) {
        'word-meaning' => 'Word meaning',
        'overlong' => 'Overlong',
        final other => other.isEmpty ? 'Note' : other[0].toUpperCase() + other.substring(1),
      };
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed) => Container(
          width: DsGeom.row,
          height: DsGeom.row,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Icon(icon, size: 22, color: Ds.soft),
        ),
      );
}
