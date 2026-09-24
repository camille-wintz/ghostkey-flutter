import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/mara/providers.dart';
import 'package:ghostkey/screens/mara/cards/board_screen.dart';
import 'package:ghostkey/screens/mara/chapters/book_list.dart';
import 'package:ghostkey/screens/mara/chapters/changeset_view.dart';
import 'package:ghostkey/screens/mara/outline/outline_page_body.dart';
import 'package:ghostkey/screens/mara/chapters/proposal_view.dart';
import 'package:ghostkey/server/dto/plan.dart';
import 'package:ghostkey/server/dto/projects.dart';
import 'package:ghostkey/server/providers.dart';
import 'package:ghostkey/ui/hold_to_drag.dart';

// The Mara screens built over fixed reads, with no server behind them: that
// each face lays out and draws what it is handed. A phone is still the proof.

Map<String, dynamic> docJson(String id, String filename) =>
    {'id': id, 'kind': 'chapter', 'filename': filename, 'version': 1, 'word_count': 1200, 'updated_at': ''};

final project = ProjectFull.fromJson({
  'project': {'id': 'p', 'name': 'Book', 'title': 'Book', 'active_draft_id': 'd1', 'saved_prompts': <Object>[]},
  'draft': {'id': 'd1', 'name': 'First draft', 'version': 1},
  'chapters': [
    docJson('c1', 'One.md'),
    {
      'id': 'g',
      'name': 'Part Two',
      'chapters': [docJson('c2', 'Two.md'), docJson('c3', 'Three.md')],
    },
  ],
  'notes': <Object>[],
  'assets': <Object>[],
});

final board = StoryMap.fromJson({
  'id': 'm',
  'template_id': null,
  'name': 'Blank board',
  'source': 'authored',
  'nodes': [
    {'id': 'a', 'title': 'First', 'description': 'It begins', 'chapters': <Object>[], 'cards': <Object>[]},
    {'id': 'b', 'title': 'Second', 'description': '', 'chapters': <Object>[], 'cards': <Object>[]},
    {'id': 'l', 'kind': 'label', 'title': 'Act Two', 'description': '', 'chapters': <Object>[], 'cards': <Object>[]},
    {'id': 'c', 'title': 'Third', 'description': '', 'chapters': <Object>[], 'cards': <Object>[]},
  ],
  'layout': {'format_version': 4, 'positions': <String, Object>{}, 'roots': <Object>[]},
});

Widget host(Widget child, AuthoredOutline outline) => ProviderScope(
      overrides: [
        projectProvider('p').overrideWith((ref) async => project),
        authoredOutlineProvider('p').overrideWith((ref) async => outline),
        storyMapsProvider('p').overrideWith((ref) async => [board]),
        storyTemplatesProvider.overrideWith((ref) async => const <StoryTemplate>[]),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

/// A phone-width screen tall enough that every row of these lists is built.
void tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a board lays out its cards, its adds and its generate', (tester) async {
    tallPhone(tester);
    await tester.pumpWidget(host(BoardScreen(projectId: 'p', board: board), const AuthoredOutline(text: '')));
    await tester.pump();
    expect(find.text('Blank board'), findsOneWidget);
    expect(find.text('It begins'), findsOneWidget);
    expect(find.text('Act Two'), findsOneWidget);
    expect(find.byType(HoldToDrag), findsNWidgets(4));
    expect(find.text('Add card'), findsOneWidget);
    expect(find.text('GENERATE CHAPTERS'), findsOneWidget);
  });

  testWidgets('a proposal lays out its filters, parts, chapters and commit', (tester) async {
    tallPhone(tester);
    final outline = AuthoredOutline.fromJson({
      'text': '',
      'chapters': [
        {
          'id': 'x',
          'title': 'Opening',
          'notes': '',
          'origin': 'outline',
          'match': {'document_id': 'c1', 'filename': 'One.md', 'words': 1200, 'confidence': 'strong', 'reason': 'r'},
          'use_as_reference': true,
          'copy_prose': true,
        },
        {
          'id': 'pt',
          'name': 'Part Two',
          'chapters': [
            {'id': 'y', 'title': 'New ground', 'notes': '', 'origin': 'outline', 'words': 3000, 'use_as_reference': false, 'copy_prose': false},
          ],
        },
      ],
      'matched_draft_id': 'd1',
    });
    await tester.pumpWidget(host(ProposalView(projectId: 'p', outline: outline, project: project), outline));
    await tester.pump();
    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('Opening'), findsOneWidget);
    expect(find.text('PART TWO'), findsOneWidget);
    expect(find.text('~3,000 w'.replaceAll(',', ' ')), findsOneWidget);
    expect(find.text('CREATE 2 CHAPTERS'), findsOneWidget);
    expect(find.textContaining('Start chapters from their existing text'), findsOneWidget);
  });

  testWidgets('a changeset lays its changes over the book', (tester) async {
    tallPhone(tester);
    final outline = AuthoredOutline.fromJson({
      'text': '',
      'changeset': {
        'summary': 'The ending changes.',
        'questions': <Object>[],
        'ops': [
          {
            'id': 'rm',
            'op': 'remove',
            'chapters': [
              {'document_id': 'c3', 'filename': 'Three.md'},
            ],
            'reason': 'It no longer happens.',
          },
          {
            'id': 'add',
            'op': 'add',
            'with': [
              {'title': 'Coda', 'notes': '', 'entities': <Object>[], 'from': null},
            ],
            'after': {'document_id': 'c3', 'filename': 'Three.md'},
            'reason': 'A new ending.',
          },
        ],
        'ledger': null,
        'verdict': null,
      },
      'changeset_draft_id': 'd1',
      'intent': 'Make the ending happy',
    });
    await tester.pumpWidget(host(ChangesetView(projectId: 'p', outline: outline, project: project), outline));
    await tester.pump();
    expect(find.text('Make the ending happy'), findsOneWidget);
    expect(find.text('REMOVED'), findsWidgets);
    expect(find.text('Coda'), findsOneWidget);
    expect(find.text('2 of 2 changes accepted'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.text('1 of 2 changes accepted · 1 skipped'), findsOneWidget);
  });

  testWidgets('the outline counts its words and offers the break', (tester) async {
    tallPhone(tester);
    const outline = AuthoredOutline(text: 'She leaves the city at dawn.');
    await tester.pumpWidget(host(const OutlinePageBody(projectId: 'p', initial: 'She leaves the city at dawn.'), outline));
    await tester.pump();
    expect(find.text('She leaves the city at dawn.'), findsOneWidget);
    expect(find.textContaining('6 words · Not broken into chapters yet'), findsOneWidget);
    expect(find.text('BREAK INTO CHAPTERS'), findsOneWidget);
  });

  testWidgets('the book lists its chapters under their parts', (tester) async {
    tallPhone(tester);
    await tester.pumpWidget(host(BookList(projectId: 'p', tree: project.chapters), const AuthoredOutline(text: '')));
    await tester.pump();
    expect(find.text('One'), findsOneWidget);
    expect(find.text('PART TWO'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);
  });
}
