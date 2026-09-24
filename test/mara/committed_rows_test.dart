import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/poltergeist/plan_rules.dart';
import 'package:ghostkey/server/dto/projects.dart';

DocumentSummary doc(String id, {int words = 0, int version = 1}) =>
    DocumentSummary(id: id, kind: DocumentKind.chapter, filename: '$id.md', version: version, wordCount: words, updatedAt: '');

const now = '2026-09-24T10:00:00.000Z';

void main() {
  test('a commit’s chapters get their notes, their target and their write', () {
    final tree = <ChaptersListEntry>[doc('a'), doc('b', words: 800, version: 3)];
    // The reconcile has already met `b` and guessed a line edit from its words.
    final reconciled = reconcilePlan(ProjectPlan.seeded(const [], now), tree, now: now, newId: () => 'r-b').plan;
    final plan = withCommittedChapters(
      reconciled.withChapters(reconciled.chapters.where((r) => r.documentId == 'b').toList()),
      [
        (documentId: 'a', notes: 'Open on the storm', words: 2500),
        (documentId: 'b', notes: 'Kept from the old draft', words: null),
      ],
      tree,
      now: now,
      newId: () => 'r-a',
    );
    final a = plan.chapters.firstWhere((r) => r.documentId == 'a');
    final b = plan.chapters.firstWhere((r) => r.documentId == 'b');
    expect((a.notes, a.targetWords, a.action), ('Open on the storm', 2500, PlanActionKind.write));
    expect((b.notes, b.targetWords, b.action), ('Kept from the old draft', null, PlanActionKind.write));
    // Anchored on what the chapter holds now, so the write reads as done
    // only once it is rewritten.
    expect(b.pending!.anchor.version, 3);
    expect(b.pending!.anchor.words, 800);
  });

  test('a note or a target the author already has is never overwritten', () {
    final tree = <ChaptersListEntry>[doc('a')];
    final seeded = ProjectPlan.seeded([
      PlanChapter.linked(id: 'r', documentId: 'a', filename: 'a.md', action: null).copyWith(notes: 'Mine', targetWords: 900),
    ], now);
    final plan = withCommittedChapters(seeded, [(documentId: 'a', notes: 'Theirs', words: 3000)], tree, now: now, newId: () => 'x');
    final row = plan.chapters.single;
    expect((row.notes, row.targetWords), ('Mine', 900));
  });

  test('a target is set and cleared on its row', () {
    final plan = ProjectPlan.seeded([
      PlanChapter.linked(id: 'r', documentId: 'a', filename: 'a.md', action: null),
    ], now);
    expect(withRowTargetWords(plan, 'r', 1200).chapters.single.targetWords, 1200);
    expect(withRowTargetWords(withRowTargetWords(plan, 'r', 1200), 'r', null).chapters.single.targetWords, isNull);
  });
}
