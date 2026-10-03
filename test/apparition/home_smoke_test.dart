import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/next_scene/next_scene_finder.dart';
import 'package:ghostkey/rewards/ledger.dart';
import 'package:ghostkey/rewards/providers.dart';
import 'package:ghostkey/screens/apparition/home/apparition_home.dart';
import 'package:ghostkey/screens/project/project_root.dart';
import 'package:ghostkey/server/dto/projects.dart';
import 'package:ghostkey/server/dto/rewards.dart';
import 'package:ghostkey/server/providers.dart';

// Apparition's home built over fixed reads, with no server behind it: that
// each section lays out at a phone's width and the range switch redraws the
// chart. A phone is still the proof.

Map<String, dynamic> docJson(String id, String filename, String updatedAt) =>
    {'id': id, 'kind': 'chapter', 'filename': filename, 'version': 1, 'word_count': 1200, 'updated_at': updatedAt};

final project = ProjectFull.fromJson({
  'project': {'id': 'p', 'name': 'Book', 'title': 'Book', 'active_draft_id': 'd1', 'saved_prompts': <Object>[]},
  'draft': {'id': 'd1', 'name': 'First draft', 'version': 1},
  'chapters': [
    docJson('c1', 'One.md', '2026-09-01T10:00:00Z'),
    docJson('c2', 'A rather long chapter title that has to wrap.md', '2026-10-01T10:00:00Z'),
  ],
  'notes': <Object>[],
  'assets': <Object>[],
});

Rewards ledger(int days) {
  final end = DateTime.utc(2026, 10, 2);
  return Rewards(
    target: 500,
    writtenToday: 320,
    days: [
      for (var i = days - 1; i >= 0; i--)
        WordStatsDay(day: end.subtract(Duration(days: i)).toIso8601String().substring(0, 10), total: 0, written: i * 37 % 900),
    ],
    metDays: const ['2026-09-30'],
    week: const RewardWeek(start: '2026-09-28', ticked: 1, required: 5, catEarned: false),
    catsEarned: 0,
  );
}

void main() {
  testWidgets('the home lays out at a phone width and the switch redraws the chart', (tester) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final finder = NextSceneFinder(projectId: 'p');
    addTearDown(finder.dispose);
    String? opened;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectProvider('p').overrideWith((ref) async => project),
          projectPlanProvider('p').overrideWith((ref) async => null),
          projectWordCountProvider('p').overrideWith((ref) async => 2400),
          rewardsProvider(ledgerDays).overrideWith((ref) async => ledger(ledgerDays)),
          rewardsProvider(yearDays).overrideWith((ref) async => ledger(yearDays)),
          catsProvider.overrideWith((ref) async => const <Cat>[]),
          catCatalogueProvider.overrideWith((ref) async => const <CatSilhouette>[]),
        ],
        child: MaterialApp(
          home: ProjectScope(
            projectId: 'p',
            child: Scaffold(
              body: SingleChildScrollView(
                child: ApparitionHome(
                  finder: finder,
                  onOpen: (filename) => opened = filename,
                  onWrite: (_) {},
                  onStuck: (_) {},
                  stuckPending: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('WHERE YOU LEFT OFF'), findsOneWidget);
    expect(find.text('CH. 2'), findsOneWidget);
    expect(find.text('Find a scene'), findsOneWidget);
    expect(find.text('2 CHAPTERS · 2 400 WORDS'), findsOneWidget);

    await tester.tap(find.text('A rather long chapter title that has to wrap'));
    expect(opened, 'A rather long chapter title that has to wrap.md');

    await tester.tap(find.text('This year'));
    await tester.pump();
    // The year is its own read, asked for only now.
    await tester.pump();
    expect(find.text('Oct'), findsOneWidget);
    expect(find.text('Nov'), findsOneWidget);

    await tester.tap(find.text('This month'));
    await tester.pump();
    expect(find.text('Oct'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
