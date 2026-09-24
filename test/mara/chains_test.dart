import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/mara/chains.dart';
import 'package:ghostkey/server/dto/plan.dart';

StoryCard card(String id, {bool label = false, List<StoryCard> cards = const []}) =>
    StoryCard(id: id, title: id, description: '', isLabel: label, chapters: const [], cards: cards);

List<ChainPlace> places(List<ChainedCard> chained) => [for (final c in chained) c.place];

void main() {
  group('chainCards', () {
    test('the first card heads a chain and every card after it is linked', () {
      final chained = chainCards([card('a'), card('b'), card('c')], const []);
      expect(places(chained), [ChainPlace.head, ChainPlace.linked, ChainPlace.linked]);
    });

    test('a label is a heading and the card after it starts a chain', () {
      final chained = chainCards([card('a'), card('L', label: true), card('b'), card('c')], const []);
      expect(places(chained), [ChainPlace.head, ChainPlace.label, ChainPlace.head, ChainPlace.linked]);
      expect(chained[2].headByRoots, isFalse);
    });

    test('a card named in the roots heads a chain of its own', () {
      final chained = chainCards([card('a'), card('b'), card('c')], const ['b']);
      expect(places(chained), [ChainPlace.head, ChainPlace.head, ChainPlace.linked]);
      expect(chained[1].headByRoots, isTrue);
    });

    test('roots naming a card that already heads a chain change nothing', () {
      final chained = chainCards([card('a'), card('L', label: true), card('b')], const ['a', 'b']);
      expect(places(chained), [ChainPlace.head, ChainPlace.label, ChainPlace.head]);
      expect(chained[0].headByRoots, isFalse);
      expect(chained[2].headByRoots, isFalse);
    });

    test('a label never links, even two in a row or named in the roots', () {
      final chained = chainCards([card('L1', label: true), card('L2', label: true), card('a')], const ['L2']);
      expect(places(chained), [ChainPlace.label, ChainPlace.label, ChainPlace.head]);
    });
  });

  group('what the card menu offers', () {
    test('a linked card can start a chain and cannot join the card above', () {
      final linked = chainCards([card('a'), card('b')], const [])[1];
      expect(linked.canStartChain, isTrue);
      expect(linked.canJoinAbove, isFalse);
    });

    test('a head only through the roots can join the card above', () {
      final rooted = chainCards([card('a'), card('b')], const ['b'])[1];
      expect(rooted.canStartChain, isFalse);
      expect(rooted.canJoinAbove, isTrue);
    });

    test('the first card and a card after a label can do neither', () {
      final chained = chainCards([card('a'), card('L', label: true), card('b')], const []);
      for (final c in [chained[0], chained[1], chained[2]]) {
        expect(c.canStartChain, isFalse);
        expect(c.canJoinAbove, isFalse);
      }
    });
  });

  test('a legacy nested board reads depth-first', () {
    final map = StoryMap(
      id: 'm',
      name: null,
      source: 'authored',
      nodes: [
        card('a', cards: [card('a1'), card('a2', cards: [card('a2x')])]),
        card('b'),
      ],
    );
    expect([for (final c in map.cards) c.id], ['a', 'a1', 'a2', 'a2x', 'b']);
  });

  group('cardAboveDrop', () {
    test('moving down lands after the card that was below', () {
      expect(cardAboveDrop(['a', 'b', 'c', 'd'], 0, 2), 'c');
    });

    test('moving up lands after the card above the new place', () {
      expect(cardAboveDrop(['a', 'b', 'c', 'd'], 3, 1), 'a');
    });

    test('moving to the top lands first', () {
      expect(cardAboveDrop(['a', 'b', 'c'], 2, 0), isNull);
    });
  });
}
