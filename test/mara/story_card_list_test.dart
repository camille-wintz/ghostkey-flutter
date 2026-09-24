import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/screens/mara/cards/story_card_list.dart';
import 'package:ghostkey/server/dto/plan.dart';
import 'package:ghostkey/ui/hold_to_drag.dart';

StoryCard card(String id, {bool label = false, String description = '', String? key}) =>
    StoryCard(id: id, key: key, title: id, description: description, isLabel: label, chapters: const [], cards: const []);

final cards = [
  card('One', description: 'It begins'),
  card('Two', key: 'beat_two'),
  card('Act Two', label: true),
  card('Three'),
  card('Four'),
];

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('draws the chains: joined cards, a new chain after a label and at a root', (tester) async {
    await tester.pumpWidget(host(StoryCardList(cards: cards, roots: const ['Four'], hints: const {'beat_two': 'What turns?'})));
    expect(find.byKey(const ValueKey('chain-head-One')), findsOneWidget);
    expect(find.byKey(const ValueKey('chain-link-Two')), findsOneWidget);
    expect(find.byKey(const ValueKey('chain-head-Three')), findsOneWidget);
    expect(find.byKey(const ValueKey('chain-head-Four')), findsOneWidget);
    // A label is a heading, with no place in a chain.
    expect(find.text('Act Two'), findsOneWidget);
    expect(find.byKey(const ValueKey('chain-head-Act Two')), findsNothing);
    expect(find.byKey(const ValueKey('chain-link-Act Two')), findsNothing);
    // An unfilled card shows its beat's question in its words' place.
    expect(find.text('What turns?'), findsOneWidget);
    expect(find.text('It begins'), findsOneWidget);
  });

  testWidgets('read-only: nothing lifts and nothing opens', (tester) async {
    await tester.pumpWidget(host(StoryCardList(cards: cards, roots: const [])));
    expect(find.byType(HoldToDrag), findsNothing);
    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.bySemanticsLabel('More'), findsNothing);
  });

  testWidgets('editable: every card can lift, and a tap opens it', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(host(StoryCardList(
      cards: cards,
      roots: const [],
      onMove: (_, _) {},
      onOpen: (c) => opened.add(c.id),
      onMenu: (_) {},
    )));
    expect(find.byType(HoldToDrag), findsNWidgets(cards.length));
    await tester.tap(find.text('It begins'));
    expect(opened, ['One']);
  });

  testWidgets('a write in flight holds every card still', (tester) async {
    await tester.pumpWidget(host(StoryCardList(cards: cards, roots: const [], onMove: (_, _) {}, busy: true)));
    final lifts = tester.widgetList<HoldToDrag>(find.byType(HoldToDrag));
    expect(lifts.every((l) => !l.enabled), isTrue);
  });
}
