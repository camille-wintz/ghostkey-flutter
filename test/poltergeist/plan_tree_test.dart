import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/poltergeist/plan_rules.dart';
import 'package:ghostkey/poltergeist/plan_tree.dart';
import 'package:ghostkey/server/dto/projects.dart';

DocumentSummary doc(String id, String filename) => DocumentSummary(
      id: id,
      kind: DocumentKind.chapter,
      filename: filename,
      version: 1,
      wordCount: 10,
      updatedAt: '',
    );

const now = '2026-09-09T10:00:00.000Z';

String Function() ids() {
  var n = 0;
  return () => 'row-${++n}';
}

void main() {
  final tree = [
    doc('a', 'One.md'),
    ChapterGroup(name: 'Part 2', chapters: [doc('b', 'Two.md'), doc('c', 'Three.md')]),
    doc('d', 'Four.md'),
  ];

  test('projects rows onto the tree: loose rows bare, folders with their rows', () {
    final plan = seedPlan(tree, now: now, newId: ids());
    final entries = planTree(plan.chapters, tree);
    expect(entries.length, 3);
    expect((entries[0] as PlanRowEntry).row.documentId, 'a');
    final folder = entries[1] as PlanFolderEntry;
    expect(folder.name, 'Part 2');
    expect(folder.rows.map((r) => r.documentId), ['b', 'c']);
    expect((entries[2] as PlanRowEntry).row.documentId, 'd');
  });

  test('a missing row trails the row it followed, at the top level', () {
    final plan = seedPlan(tree, now: now, newId: ids());
    final without = [doc('a', 'One.md'), ChapterGroup(name: 'Part 2', chapters: [doc('b', 'Two.md')]), doc('d', 'Four.md')];
    final reconciled = reconcilePlan(plan, without, now: now, newId: ids()).plan;
    final entries = planTree(reconciled.chapters, without);
    expect(entries.length, 4);
    expect((entries[1] as PlanFolderEntry).rows.map((r) => r.documentId), ['b']);
    final orphan = entries[2] as PlanRowEntry;
    expect(orphan.row.title, 'Three.md');
    expect(orphan.row.missing, isTrue);
    expect((entries[3] as PlanRowEntry).row.documentId, 'd');
  });

  test('a chapter with no row yet stays hidden until the reconcile mints one', () {
    final plan = seedPlan([doc('a', 'One.md')], now: now, newId: ids());
    final entries = planTree(plan.chapters, [doc('a', 'One.md'), doc('z', 'New.md')]);
    expect(entries.length, 1);
  });

  test('the flat list opens and shuts folders and marks the last row of each run', () {
    final plan = seedPlan(tree, now: now, newId: ids());
    final entries = planTree(plan.chapters, tree);
    final open = planListItems(entries, (_) => true);
    expect(open.map((i) => i.runtimeType), [PlanRowItem, PlanFolderHeaderItem, PlanRowItem, PlanRowItem, PlanRowItem]);
    expect((open[0] as PlanRowItem).last, isTrue);
    expect((open[2] as PlanRowItem).last, isFalse);
    expect((open[3] as PlanRowItem).last, isTrue);
    expect((open[3] as PlanRowItem).inFolder, isTrue);
    final shut = planListItems(entries, (_) => false);
    expect(shut.length, 3);
    expect((shut[1] as PlanFolderHeaderItem).open, isFalse);
    expect((shut[1] as PlanFolderHeaderItem).rows.length, 2);
  });
}
