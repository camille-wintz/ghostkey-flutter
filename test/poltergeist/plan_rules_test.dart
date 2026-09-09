import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/poltergeist/plan_rules.dart';
import 'package:ghostkey/server/dto/projects.dart';

DocumentSummary doc(String id, String filename, {int version = 1, int? words = 100}) => DocumentSummary(
      id: id,
      kind: DocumentKind.chapter,
      filename: filename,
      version: version,
      wordCount: words,
      updatedAt: '',
    );

const now = '2026-09-09T10:00:00.000Z';
const later = '2026-09-09T11:00:00.000Z';

String Function() ids() {
  var n = 0;
  return () => 'row-${++n}';
}

PlanChapter rowOf(ProjectPlan plan, String documentId) => plan.chapters.firstWhere((c) => c.documentId == documentId);

void main() {
  group('seedPlan', () {
    test('lists every chapter, folders flattened, owing a line edit or a write when empty', () {
      final plan = seedPlan(
        [
          doc('a', 'One.md'),
          ChapterGroup(name: 'Part 2', chapters: [doc('b', 'Two.md', words: 0), doc('c', 'Three.md')]),
        ],
        now: now,
        newId: ids(),
      );
      expect(plan.formatVersion, planFormatVersion);
      expect(plan.seededAt, now);
      expect(plan.chapters.map((c) => c.documentId), ['a', 'b', 'c']);
      expect(plan.chapters.map((c) => c.id), ['row-1', 'row-2', 'row-3']);
      expect(plan.chapters[0].action, PlanActionKind.lineEdit);
      expect(plan.chapters[1].action, PlanActionKind.write);
      expect(plan.chapters[0].pending!.anchor.version, 1);
      expect(plan.chapters[0].pending!.anchor.words, 100);
      expect(plan.chapters[0].title, 'One.md');
      expect(plan.chapters[0].label, 'One');
      // The wire shape carries everything the desktop reads.
      final json = plan.toJson();
      expect(json['reconciled_at'], now);
      final row = (json['chapters'] as List).first as Map<String, dynamic>;
      expect(row.keys, containsAll(['id', 'title', 'document_id', 'filename', 'notes', 'action', 'history', 'done', 'missing']));
      final action = row['action'] as Map<String, dynamic>;
      expect(action['kind'], 'line_edit');
      expect(action['ready'], false);
      expect(action['evidence'], isNull);
      expect((action['anchor'] as Map<String, dynamic>)['fingerprint'], isNull);
    });

    test('an empty manuscript seeds an empty plan', () {
      final plan = seedPlan(const [], now: now, newId: ids());
      expect(plan.chapters, isEmpty);
    });
  });

  group('reconcilePlan', () {
    test('changes nothing on a plan already in step, and asks for no save', () {
      final tree = [doc('a', 'One.md'), doc('b', 'Two.md')];
      final seeded = seedPlan(tree, now: now, newId: ids());
      final result = reconcilePlan(seeded, tree, now: later, newId: ids());
      expect(result.changed, isFalse);
      expect(result.plan.reconciledAt, now);
    });

    test('follows a rename by id and stamps reconciled_at', () {
      final seeded = seedPlan([doc('a', 'One.md')], now: now, newId: ids());
      final result = reconcilePlan(seeded, [doc('a', 'Uno.md', version: 2)], now: later, newId: ids());
      expect(result.changed, isTrue);
      expect(result.plan.reconciledAt, later);
      expect(result.plan.chapters.single.title, 'Uno.md');
      expect(result.plan.chapters.single.filename, 'Uno.md');
    });

    test('a vanished chapter flags its row missing, and keeps its place', () {
      final tree = [doc('a', 'One.md'), doc('b', 'Two.md'), doc('c', 'Three.md')];
      final seeded = seedPlan(tree, now: now, newId: ids());
      final result = reconcilePlan(seeded, [doc('a', 'One.md'), doc('c', 'Three.md')], now: later, newId: ids());
      final rows = result.plan.chapters;
      expect(rows.map((r) => r.title), ['One.md', 'Two.md', 'Three.md']);
      expect(rows[1].missing, isTrue);
      expect(rows[1].documentId, isNull);
      expect(rows[1].filename, isNull);
      expect(rows[1].action, PlanActionKind.lineEdit, reason: 'the action waits on the author');
    });

    test('a vanished chapter with a planned delete takes its row with it', () {
      final tree = [doc('a', 'One.md'), doc('b', 'Two.md')];
      final seeded = seedPlan(tree, now: now, newId: ids());
      final planned = applyPlanOp(seeded, seeded.chapters[1].id, PlanOp.assign,
          kind: PlanActionKind.delete, tree: tree, now: now)!;
      final result = reconcilePlan(planned, [doc('a', 'One.md')], now: later, newId: ids());
      expect(result.plan.chapters.map((r) => r.documentId), ['a']);
    });

    test('a missing row relinks when a chapter of the same name reappears', () {
      final seeded = seedPlan([doc('a', 'One.md')], now: now, newId: ids());
      final missing = reconcilePlan(seeded, const [], now: later, newId: ids()).plan;
      expect(missing.chapters.single.missing, isTrue);
      final back = reconcilePlan(missing, [doc('a2', 'One.md', version: 3)], now: later, newId: ids()).plan;
      final row = back.chapters.single;
      expect(row.missing, isFalse);
      expect(row.documentId, 'a2');
      expect(row.id, seeded.chapters.single.id, reason: 'the row survives; its notes and history are the author\'s');
    });

    test('an adopted row owing its write re-anchors on empty, so words on the page make it ready', () {
      final seeded = seedPlan([doc('a', 'One.md', words: 0)], now: now, newId: ids());
      expect(seeded.chapters.single.action, PlanActionKind.write);
      final missing = reconcilePlan(seeded, const [], now: later, newId: ids()).plan;
      final back = reconcilePlan(missing, [doc('a2', 'One.md', version: 5, words: 900)], now: later, newId: ids()).plan;
      final action = back.chapters.single.pending!;
      expect(action.kind, PlanActionKind.write);
      expect(action.ready, isTrue);
      expect(action.evidence!.wordsAfter, 900);
      expect(action.evidence!.wordsBefore, 0);
    });

    test('chapters the board has never seen join as rows, in manuscript order', () {
      final seeded = seedPlan([doc('a', 'One.md'), doc('c', 'Three.md')], now: now, newId: ids());
      final result = reconcilePlan(
        seeded,
        [doc('a', 'One.md'), doc('b', 'Two.md', words: 0), doc('c', 'Three.md')],
        now: later,
        newId: () => 'fresh',
      );
      expect(result.changed, isTrue);
      final rows = result.plan.chapters;
      expect(rows.map((r) => r.documentId), ['a', 'b', 'c']);
      expect(rows[1].id, 'fresh');
      expect(rows[1].action, PlanActionKind.write, reason: 'an empty chapter owes its write');
    });

    test('a move completes when the predecessor changes', () {
      final tree = [doc('a', 'One.md'), doc('b', 'Two.md'), doc('c', 'Three.md')];
      final seeded = seedPlan(tree, now: now, newId: ids());
      final tagged = applyPlanOp(seeded, rowOf(seeded, 'c').id, PlanOp.assign,
          kind: PlanActionKind.move, tree: tree, now: now)!;
      expect(rowOf(tagged, 'c').pending!.anchor.prevDocumentId, 'b');

      final same = reconcilePlan(tagged, tree, now: later, newId: ids());
      expect(rowOf(same.plan, 'c').action, PlanActionKind.move);

      final moved = reconcilePlan(tagged, [doc('c', 'Three.md'), doc('a', 'One.md'), doc('b', 'Two.md')],
          now: later, newId: ids());
      final row = moved.plan.chapters.first;
      expect(row.documentId, 'c', reason: 'rows follow manuscript order');
      expect(row.action, isNull);
      expect(row.history.single.kind, PlanActionKind.move);
      expect(row.history.single.completedAt, later);
      expect(row.done, isFalse, reason: 'moving never finishes a chapter');
    });

    test('a write turns ready once the chapter has words, and not before', () {
      final seeded = seedPlan([doc('a', 'One.md', words: 0)], now: now, newId: ids());
      final still = reconcilePlan(seeded, [doc('a', 'One.md', version: 1, words: 0)], now: later, newId: ids());
      expect(still.changed, isFalse);
      final bumped = reconcilePlan(seeded, [doc('a', 'One.md', version: 4, words: 0)], now: later, newId: ids());
      expect(bumped.plan.chapters.single.pending!.ready, isFalse);
      final written = reconcilePlan(seeded, [doc('a', 'One.md', version: 4, words: 1200)], now: later, newId: ids());
      final action = written.plan.chapters.single.pending!;
      expect(action.ready, isTrue);
      expect(readyEvidence(written.plan.chapters.single), 'Written? 1200 words on the page.');
    });

    test('a phone-anchored line edit reads a moved version as looking done; a rewrite never does', () {
      final tree = [doc('a', 'One.md'), doc('b', 'Two.md')];
      final seeded = seedPlan(tree, now: now, newId: ids());
      final tagged = applyPlanOp(seeded, rowOf(seeded, 'b').id, PlanOp.assign,
          kind: PlanActionKind.rewrite, tree: tree, now: now)!;
      final moved = reconcilePlan(tagged, [doc('a', 'One.md', version: 2, words: 150), doc('b', 'Two.md', version: 9, words: 40)],
          now: later, newId: ids());
      final lineEdit = rowOf(moved.plan, 'a').pending!;
      expect(lineEdit.kind, PlanActionKind.lineEdit);
      expect(lineEdit.ready, isTrue);
      expect(lineEdit.evidence, isNull);
      expect(readyEvidence(rowOf(moved.plan, 'a')), 'Line edited?');
      final rewrite = rowOf(moved.plan, 'b').pending!;
      expect(rewrite.kind, PlanActionKind.rewrite);
      expect(rewrite.ready, isFalse);
    });

    test('a desktop-measured line edit keeps the desktop\'s verdict', () {
      final stored = ProjectPlan.fromJson({
        'format_version': 2,
        'seeded_at': now,
        'reconciled_at': now,
        'chapters': [
          {
            'id': 'r1',
            'title': 'One.md',
            'document_id': 'a',
            'filename': 'One.md',
            'notes': 'keep me',
            'action': {
              'kind': 'line_edit',
              'assigned_at': now,
              'anchor': {'version': 1, 'words': 100, 'fingerprint': 'abc', 'prev_document_id': null},
              'ready': true,
              'evidence': {'churn': 0.42, 'words_before': 100, 'words_after': 130},
            },
            'history': <Map<String, dynamic>>[],
            'done': false,
            'missing': false,
            'desktop_only': 'echoed',
          },
        ],
      });
      final result = reconcilePlan(stored, [doc('a', 'One.md', version: 7, words: 130)], now: later, newId: ids());
      expect(result.changed, isFalse);
      final row = result.plan.chapters.single;
      expect(row.pending!.evidence!.churn, 0.42);
      expect(readyEvidence(row), 'Line edited? 42% changed since tagged, 100 → 130 words.');
      expect(row.toJson()['desktop_only'], 'echoed');
      // Back on the anchor's version, the verdict is withdrawn.
      final reverted = reconcilePlan(stored, [doc('a', 'One.md', version: 1, words: 100)], now: later, newId: ids());
      expect(reverted.changed, isTrue);
      expect(reverted.plan.chapters.single.pending!.ready, isFalse);
      expect(reverted.plan.chapters.single.pending!.evidence, isNull);
    });

    test('an action with no anchor captures one now', () {
      final stored = ProjectPlan.fromJson({
        'format_version': 2,
        'chapters': [
          {'id': 'r1', 'title': 'One.md', 'document_id': 'a', 'action': {'kind': 'rewrite'}},
        ],
      });
      final result = reconcilePlan(stored, [doc('a', 'One.md', version: 3, words: 80)], now: later, newId: ids());
      final anchor = result.plan.chapters.single.pending!.anchor;
      expect(anchor.version, 3);
      expect(anchor.words, 80);
    });

    test('a plan of another format is left alone', () {
      final v1 = ProjectPlan.fromJson({'format_version': 1, 'chapters': <Map<String, dynamic>>[]});
      final result = reconcilePlan(v1, [doc('a', 'One.md')], now: later, newId: ids());
      expect(result.changed, isFalse);
      expect(identical(result.plan, v1), isTrue);
    });

    test('a row with a `done` the desktop never wrote reads done after its line edit', () {
      final row = PlanChapter.fromJson({
        'id': 'r1',
        'title': 'One.md',
        'history': [
          {'kind': 'write', 'completed_at': now},
          {'kind': 'line_edit', 'completed_at': now},
        ],
      });
      expect(row.done, isTrue);
      expect(PlanChapter.fromJson({'id': 'r2', 'title': 'Two.md'}).done, isFalse);
    });
  });

  group('applyPlanOp', () {
    final tree = [doc('a', 'One.md', version: 2, words: 500), doc('b', 'Two.md')];
    final seeded = seedPlan(tree, now: now, newId: ids());
    final rowId = seeded.chapters.first.id;

    test('assign anchors a textual action on the chapter and clears done', () {
      final done = applyPlanOp(seeded, rowId, PlanOp.done, tree: tree, now: now)!;
      expect(done.chapters.first.done, isTrue);
      expect(done.chapters.first.action, isNull);
      final assigned = applyPlanOp(done, rowId, PlanOp.assign, kind: PlanActionKind.rewrite, tree: tree, now: later)!;
      final row = assigned.chapters.first;
      expect(row.done, isFalse);
      expect(row.pending!.kind, PlanActionKind.rewrite);
      expect(row.pending!.assignedAt, later);
      expect(row.pending!.anchor.version, 2);
      expect(row.pending!.anchor.words, 500);
    });

    test('assign refuses a row with no chapter', () {
      final missing = reconcilePlan(seeded, [doc('b', 'Two.md')], now: later, newId: ids()).plan;
      expect(applyPlanOp(missing, rowId, PlanOp.assign, kind: PlanActionKind.write, tree: tree, now: later), isNull);
      expect(applyPlanOp(seeded, rowId, PlanOp.assign, tree: tree, now: later), isNull, reason: 'no kind');
      expect(applyPlanOp(seeded, 'nope', PlanOp.clear, tree: tree, now: later), isNull, reason: 'no row');
    });

    test('clear drops the action and leaves history alone', () {
      final cleared = applyPlanOp(seeded, rowId, PlanOp.clear, tree: tree, now: later)!;
      expect(cleared.chapters.first.action, isNull);
      expect(cleared.chapters.first.history, isEmpty);
      expect(cleared.chapters.first.done, isFalse);
    });

    test('confirm needs a ready action', () {
      expect(applyPlanOp(seeded, rowId, PlanOp.confirm, tree: tree, now: later), isNull);
    });

    test('confirming a write chains a line edit anchored now; confirming that finishes the chapter', () {
      final empty = [doc('a', 'One.md', version: 1, words: 0)];
      final plan = seedPlan(empty, now: now, newId: ids());
      final id = plan.chapters.single.id;
      final written = reconcilePlan(plan, [doc('a', 'One.md', version: 6, words: 700)], now: later, newId: ids()).plan;
      final confirmed = applyPlanOp(written, id, PlanOp.confirm, tree: [doc('a', 'One.md', version: 6, words: 700)], now: later)!;
      var row = confirmed.chapters.single;
      expect(row.history.single.kind, PlanActionKind.write);
      expect(row.pending!.kind, PlanActionKind.lineEdit);
      expect(row.pending!.anchor.version, 6);
      expect(row.pending!.anchor.words, 700);
      expect(row.done, isFalse);

      final edited = reconcilePlan(confirmed, [doc('a', 'One.md', version: 8, words: 720)], now: later, newId: ids()).plan;
      expect(edited.chapters.single.pending!.ready, isTrue);
      final finished = applyPlanOp(edited, id, PlanOp.confirm, tree: [doc('a', 'One.md', version: 8, words: 720)], now: later)!;
      row = finished.chapters.single;
      expect(row.action, isNull);
      expect(row.done, isTrue);
      expect(row.history.map((h) => h.kind), [PlanActionKind.write, PlanActionKind.lineEdit]);
    });

    test('undone lifts done and nothing else', () {
      final done = applyPlanOp(seeded, rowId, PlanOp.done, tree: tree, now: now)!;
      final undone = applyPlanOp(done, rowId, PlanOp.undone, tree: tree, now: later)!;
      expect(undone.chapters.first.done, isFalse);
      expect(undone.chapters.first.action, isNull);
    });

    test('notes edit in place; only missing rows can be removed', () {
      final noted = withRowNotes(seeded, rowId, 'Open on the storm.');
      expect(noted.chapters.first.notes, 'Open on the storm.');
      expect(withoutRow(noted, rowId), isNull);
      final missing = reconcilePlan(noted, [doc('b', 'Two.md')], now: later, newId: ids()).plan;
      expect(withoutRow(missing, rowId)!.chapters.map((c) => c.documentId), ['b']);
    });
  });

  group('progress and counts', () {
    test('clean over total, missing rows never clean', () {
      final tree = [doc('a', 'One.md'), doc('b', 'Two.md'), doc('c', 'Three.md')];
      final seeded = seedPlan(tree, now: now, newId: ids());
      expect(planProgress(seeded).fraction, 0);
      expect(planProgress(null).total, 0);
      final one = applyPlanOp(seeded, seeded.chapters[0].id, PlanOp.done, tree: tree, now: now)!;
      final two = applyPlanOp(one, one.chapters[1].id, PlanOp.clear, tree: tree, now: now)!;
      final gone = reconcilePlan(two, [doc('a', 'One.md'), doc('b', 'Two.md')], now: later, newId: ids()).plan;
      expect(planProgress(gone).clean, 2);
      expect(planProgress(gone).total, 3);
      expect(owedCount(gone.chapters, PlanActionKind.lineEdit), 1);
      expect(cleanCount(gone.chapters), 2);
      expect(doneCount(gone.chapters), 1);
    });
  });

  group('PlanChapter.copyWith(action:)', () {
    test('writes a whole action, never a bare kind, and clears done', () {
      final row = PlanChapter.fromJson({'id': 'r', 'title': 'T.md', 'document_id': 'a', 'done': true});
      final next = row.copyWith(action: PlanActionKind.rewrite);
      final action = next.toJson()['action'] as Map<String, dynamic>;
      expect(action['kind'], 'rewrite');
      expect(action['anchor'], isA<Map<String, dynamic>>());
      expect(action['ready'], false);
      expect(next.done, isFalse);
    });
  });
}
