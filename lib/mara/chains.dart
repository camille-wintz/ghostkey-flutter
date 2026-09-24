import '../server/dto/plan.dart';

// A board stores no wires: its cards' order, its labels and the chain heads
// the layout names ARE its links. This is the one reading of that rule on
// the phone — the card list draws from it and the card menu offers from it.
// It decides nothing about writes: a move or a relink is sent to the server,
// which owns what it does to the chains.

/// How a card sits among its board's chains.
enum ChainPlace {
  /// A heading. Never linked, and the card after it starts a chain.
  label,

  /// Starts a chain: drawn with a gap above it.
  head,

  /// Hangs under the card above it: drawn joined to it.
  linked,
}

class ChainedCard {
  const ChainedCard({required this.card, required this.place, this.headByRoots = false});
  final StoryCard card;
  final ChainPlace place;

  /// A head only because the board's roots name it — it is not first and does
  /// not follow a label, so it could hang under the card above instead.
  final bool headByRoots;

  /// "Start a new chain here" applies.
  bool get canStartChain => place == ChainPlace.linked;

  /// "Join the card above" applies.
  bool get canJoinAbove => headByRoots;
}

/// Every card of a board in reading order (legacy nesting flattened
/// depth-first), each with its place in the chains: a card heads a chain when
/// it is first, follows a label, or is named in [roots]; every other card
/// that is not a label is linked to the card above.
List<ChainedCard> chainCards(List<StoryCard> cards, Iterable<String> roots) {
  final rooted = roots.toSet();
  final out = <ChainedCard>[];
  StoryCard? above;
  for (final card in cards) {
    if (card.isLabel) {
      out.add(ChainedCard(card: card, place: ChainPlace.label));
    } else if (above == null || above.isLabel) {
      out.add(ChainedCard(card: card, place: ChainPlace.head));
    } else if (rooted.contains(card.id)) {
      out.add(ChainedCard(card: card, place: ChainPlace.head, headByRoots: true));
    } else {
      out.add(ChainedCard(card: card, place: ChainPlace.linked));
    }
    above = card;
  }
  return out;
}

/// The card a drop lands after: the one above row [to] once the card at row
/// [from] has moved there, or null when it lands first. The list's order is
/// [ids]; `to` is the row the card ends up on.
String? cardAboveDrop(List<String> ids, int from, int to) {
  final order = List<String>.from(ids);
  final moved = order.removeAt(from);
  order.insert(to, moved);
  return to > 0 ? order[to - 1] : null;
}
