import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/rewards/strike.dart';
import 'package:ghostkey/rewards/strike_card.dart';
import 'package:ghostkey/server/dto/rewards.dart';

/// The chain's own label, as the card sets it.
Finder chain(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(width: 360, child: child),
        ),
      ),
    );

void _nothing() {}

void main() {
  testWidgets('a mark lands with its words, its chain and its footnote', (tester) async {
    var gone = 0;
    await tester.pumpWidget(host(RewardStrikeCard(
      strike: const Strike(
        eyebrow: 'Today',
        headline: '100 words',
        sub: 'The page is moving.',
        short: 'The page is moving.',
        footnote: 'Next at 500',
        ring: 0.2,
        ticked: 3,
      ),
      leaving: false,
      onDismiss: () {},
      onGone: () => gone++,
    )));
    // Through the entrance: everything has risen into place.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('100 words'), findsOneWidget);
    expect(find.text('The page is moving.'), findsOneWidget);
    expect(find.text('NEXT AT 500'), findsOneWidget);
    expect(chain('3 of 7 days this week'), findsOneWidget);
    expect(gone, 0);
  });

  testWidgets('a cat shows its picture, and leaving reports when it has gone', (tester) async {
    var gone = 0;
    final cat = Cat(
      id: 'c1',
      catId: 'peony',
      name: 'Peony',
      svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#fff"/></svg>',
      reason: CatReason.week,
      earnedAt: '2026-09-20T10:00:00Z',
      weekStart: '2026-09-14',
    );
    Widget card({required bool leaving}) => RewardStrikeCard(
          key: const ValueKey(1),
          strike: Strike(
            cat: cat,
            eyebrow: 'A full week',
            headline: 'Peony',
            sub: 'Five days at the desk this week, and a cat for the shelf.',
            short: 'A full week of writing, and a cat for it.',
            footnote: 'Added to Poltergeist',
            ring: 1,
            ticked: 5,
          ),
          leaving: leaving,
          onDismiss: () {},
          onGone: () => gone++,
        );
    await tester.pumpWidget(host(card(leaving: false)));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Peony'), findsOneWidget);
    // No chain without a target — but there is one here.
    expect(chain('5 of 7 days this week'), findsOneWidget);

    await tester.pumpWidget(host(card(leaving: true)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(gone, 1);
  });

  testWidgets('the compact card keeps the number, the short line and the chain', (tester) async {
    await tester.pumpWidget(host(const RewardStrikeCard(
      compact: true,
      strike: Strike(
        eyebrow: 'Today',
        headline: '500 words',
        sub: '500 words written already. You\'re doing amazing! 200 more to your daily goal.',
        short: '200 more to your daily goal.',
        footnote: 'Kept in Poltergeist',
        ring: 1,
        ticked: 3,
      ),
      leaving: false,
      onDismiss: _nothing,
      onGone: _nothing,
    )));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('500 words'), findsOneWidget);
    expect(find.text('200 more to your daily goal.'), findsOneWidget);
    expect(chain('3 of 7 days this week'), findsOneWidget);
    // The full card's furniture stays off it.
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('KEPT IN POLTERGEIST'), findsNothing);
    expect(find.textContaining('doing amazing'), findsNothing);
  });

  testWidgets('without a target there is no chain', (tester) async {
    await tester.pumpWidget(host(RewardStrikeCard(
      strike: const Strike(
        eyebrow: 'Today',
        headline: '100 words',
        sub: 'The page is moving.',
        short: 'The page is moving.',
        footnote: 'Next at 500',
        ring: 0.2,
        ticked: null,
      ),
      leaving: false,
      onDismiss: () {},
      onGone: () {},
    )));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').endsWith('of 7 days this week')), findsNothing);
  });
}
