import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/plan.dart';

/// The author's rewording of one chapter an op writes.
typedef WrittenEdit = ({String? title, String? notes});

class ChangesetAnswers {
  const ChangesetAnswers({this.skipped = const {}, this.edits = const {}, this.carry});

  /// Ops the author skipped, by id. A skipped op is simply not applied.
  final Set<String> skipped;

  /// Op id → index into its written chapters → the author's words.
  final Map<String, Map<int, WrittenEdit>> edits;

  /// "Start chapters from their existing text": null keeps the changeset's
  /// own answer (kept chapters keep their words, rewritten ones start blank).
  final bool? carry;

  bool isSkipped(String opId) => skipped.contains(opId);

  /// A written chapter as the author has it now.
  ChangesetNewChapter written(ChangesetWrite op, int index) {
    final chapter = op.written[index];
    final edit = edits[op.id]?[index];
    return edit == null ? chapter : chapter.withText(title: edit.title, notes: edit.notes);
  }

  /// What one apply sends: skipped ops dropped, rewordings folded in.
  List<ChangesetOp> approved(List<ChangesetOp> ops) => [
        for (final op in ops)
          if (!skipped.contains(op.id))
            switch (op) {
              ChangesetWrite() when edits.containsKey(op.id) =>
                op.withWritten([for (var i = 0; i < op.written.length; i++) written(op, i)]),
              _ => op,
            },
      ];
}

/// The author's answers to a pending changeset, held here until one apply
/// sends them all. Keyed on op ids, which are minted fresh per changeset, so
/// answers to a superseded one simply stop matching.
class ChangesetReview extends Notifier<ChangesetAnswers> {
  ChangesetReview(this.projectId);
  final String projectId;

  @override
  ChangesetAnswers build() => const ChangesetAnswers();

  void toggleSkipped(String opId) {
    final next = {...state.skipped};
    if (!next.remove(opId)) next.add(opId);
    state = ChangesetAnswers(skipped: next, edits: state.edits, carry: state.carry);
  }

  void editWritten(String opId, int index, {String? title, String? notes}) {
    final opEdits = {...?state.edits[opId]};
    final was = opEdits[index];
    opEdits[index] = (title: title ?? was?.title, notes: notes ?? was?.notes);
    state = ChangesetAnswers(skipped: state.skipped, edits: {...state.edits, opId: opEdits}, carry: state.carry);
  }

  void setCarry(bool carry) => state = ChangesetAnswers(skipped: state.skipped, edits: state.edits, carry: carry);
}

final changesetReviewProvider =
    NotifierProvider.autoDispose.family<ChangesetReview, ChangesetAnswers, String>(ChangesetReview.new);
