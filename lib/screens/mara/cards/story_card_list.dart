import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ds/tokens.dart';
import '../../../mara/chains.dart';
import '../../../server/dto/plan.dart';
import '../../../ui/hold_to_drag.dart';
import 'story_card_tile.dart';

/// A board as a list: its cards in reading order, drawn in their chains —
/// linked cards joined, a gap where a chain starts, labels as headings.
///
/// Knows nothing about who shows it or where its edits go: hand it the cards
/// and, to make it editable, what a move, a tap and a menu do. With none of
/// them it is read-only and nothing lifts. With [onMove], a card held for a
/// moment lifts and drops anywhere; a drop where it started is a hold, which
/// opens its menu.
class StoryCardList extends StatefulWidget {
  const StoryCardList({
    super.key,
    required this.cards,
    required this.roots,
    this.hints = const {},
    this.onMove,
    this.onOpen,
    this.onMenu,
    this.busy = false,
    this.header,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(12, 14, 16, 32),
  });

  /// The board's cards, one level, in reading order.
  final List<StoryCard> cards;

  /// The chain heads the board names beyond the ones its order makes.
  final List<String> roots;

  /// Beat key → the question an unfilled card on that beat answers.
  final Map<String, String> hints;

  /// Move a card straight after another; null after is first.
  final void Function(String cardId, String? afterId)? onMove;
  final void Function(StoryCard card)? onOpen;
  final void Function(StoryCard card)? onMenu;

  /// A write is in flight: nothing lifts until it has landed.
  final bool busy;
  final Widget? header;
  final Widget? footer;
  final EdgeInsets padding;

  @override
  State<StoryCardList> createState() => _StoryCardListState();
}

class _StoryCardListState extends State<StoryCardList> {
  /// The order a drop left on screen until the board it was sent to comes
  /// back — the drag's own picture, never a guess at the server's answer.
  List<String>? _dropped;
  int? _lifted;

  @override
  void didUpdateWidget(StoryCardList old) {
    super.didUpdateWidget(old);
    // The board came back (its order moved), or the write ended without
    // moving it: either way the server's order is the one to show now.
    if ((old.busy && !widget.busy) || !_sameOrder(old.cards, widget.cards)) _dropped = null;
  }

  static bool _sameOrder(List<StoryCard> a, List<StoryCard> b) =>
      a.length == b.length && [for (var i = 0; i < a.length; i++) a[i].id == b[i].id].every((same) => same);

  List<StoryCard> get _cards {
    final dropped = _dropped;
    if (dropped == null) return widget.cards;
    final byId = {for (final c in widget.cards) c.id: c};
    return [for (final id in dropped) ?byId[id]];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    final chained = chainCards(cards, widget.roots);

    Widget tile(int i) {
      final c = chained[i];
      return StoryCardTile(
        chained: c,
        first: i == 0,
        joinsBelow: i + 1 < chained.length && chained[i + 1].place == ChainPlace.linked,
        hint: c.card.key == null ? null : widget.hints[c.card.key],
        onOpen: widget.onOpen == null ? null : () => widget.onOpen!(c.card),
        onMenu: widget.onMenu == null ? null : () => widget.onMenu!(c.card),
      );
    }

    final onMove = widget.onMove;
    if (onMove == null) {
      return ListView(
        padding: widget.padding,
        children: [
          ?widget.header,
          for (var i = 0; i < chained.length; i++) KeyedSubtree(key: ValueKey(chained[i].card.id), child: tile(i)),
          ?widget.footer,
        ],
      );
    }

    return ReorderableListView.builder(
      padding: widget.padding,
      buildDefaultDragHandles: false,
      header: widget.header,
      footer: widget.footer,
      itemCount: chained.length,
      proxyDecorator: _carried,
      onReorderStart: (i) {
        _lifted = i;
        unawaited(HapticFeedback.selectionClick());
      },
      onReorderEnd: (i) {
        if (i == _lifted) widget.onMenu?.call(cards[i]);
        _lifted = null;
      },
      onReorderItem: (from, to) {
        if (from == to) return;
        final ids = [for (final c in cards) c.id];
        final afterId = cardAboveDrop(ids, from, to);
        setState(() => _dropped = ids..insert(to, ids.removeAt(from)));
        onMove(cards[from].id, afterId);
      },
      itemBuilder: (context, i) => HoldToDrag(
        key: ValueKey(chained[i].card.id),
        index: i,
        enabled: !widget.busy,
        child: tile(i),
      ),
    );
  }

  /// The carried card: raised a surface step, as the chapter list's row is.
  static Widget _carried(Widget child, int index, Animation<double> animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(Ds.void_, Ds.raise, Curves.easeOutQuart.transform(animation.value)),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: child,
        ),
      );
}
