import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../mara/chains.dart';
import '../../../ui/press.dart';
import 'chain_painter.dart';

/// The gutter the chains are drawn in.
const double _gutter = 20;

/// Where a card's node sits, below the top of the card.
const double _nodeInset = 20;

/// One row of a board's card list: a label as a heading, a card as its title
/// over what happens there — or, unfilled, its beat's question, faint. A card
/// that starts a chain stands clear of the one above; one that hangs under it
/// is joined to it in the gutter.
class StoryCardTile extends StatelessWidget {
  const StoryCardTile({
    super.key,
    required this.chained,
    required this.first,
    required this.joinsBelow,
    this.hint,
    this.onOpen,
    this.onMenu,
  });

  final ChainedCard chained;

  /// The top row, which stands clear of nothing.
  final bool first;

  /// The card below hangs under this one.
  final bool joinsBelow;

  /// The template's question for an unfilled card.
  final String? hint;
  final VoidCallback? onOpen;
  final VoidCallback? onMenu;

  double get _gap => first
      ? 0
      : switch (chained.place) {
          ChainPlace.label => 26,
          ChainPlace.head => 18,
          ChainPlace.linked => 8,
        };

  @override
  Widget build(BuildContext context) {
    final card = chained.card;
    final linked = chained.place == ChainPlace.linked;
    return Stack(
      children: [
        if (!card.isLabel)
          Positioned(
            key: linked ? ValueKey('chain-link-${card.id}') : ValueKey('chain-head-${card.id}'),
            left: 0,
            top: 0,
            bottom: 0,
            width: _gutter,
            child: CustomPaint(
              painter: ChainPainter(
                nodeY: _gap + _nodeInset,
                joinedAbove: linked,
                joinsBelow: joinsBelow,
                color: Ds.edgeHi,
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(left: _gutter, top: _gap),
          child: Semantics(
            label: switch (chained.place) {
              ChainPlace.label => 'Label',
              ChainPlace.head => 'Card, starts a chain',
              ChainPlace.linked => 'Card, joined to the card above',
            },
            child: card.isLabel ? _label(card.title) : _card(),
          ),
        ),
      ],
    );
  }

  Widget _label(String title) {
    final named = title.trim().isNotEmpty;
    return Press(
      onPressed: onOpen,
      semanticLabel: named ? title : 'Unnamed label',
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
        decoration: BoxDecoration(
          color: pressed ? Ds.veil : const Color(0x00000000),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                named ? title : 'Name this part',
                style: DsStyle.prose(DsText.body, weight: FontWeight.w600, color: named ? Ds.hi : Ds.faint),
              ),
            ),
            if (onMenu case final onMenu?) _MenuButton(onPressed: onMenu),
          ],
        ),
      ),
    );
  }

  Widget _card() {
    final card = chained.card;
    final title = card.title.trim();
    final description = card.description.trim();
    final hint = this.hint;
    return Press(
      onPressed: onOpen,
      semanticLabel: title.isEmpty ? 'Untitled card' : title,
      builder: (context, pressed) => AnimatedContainer(
        duration: DsMotion.duration,
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: pressed ? Ds.raise : Ds.surf,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (title.isEmpty ? 'Untitled card' : title).toUpperCase(),
                    style: DsStyle.eyebrow(color: title.isEmpty ? Ds.faint : Ds.accent300, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description.isNotEmpty ? description : (hint ?? 'What happens here?'),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: DsStyle.prose(DsText.body, color: description.isNotEmpty ? Ds.ink : Ds.faint),
                  ),
                ],
              ),
            ),
            if (onMenu case final onMenu?) _MenuButton(onPressed: onMenu),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: 'More',
        builder: (context, pressed) => Container(
          width: 36,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Icon(LucideIcons.ellipsis, size: 16, color: Ds.mid),
        ),
      );
}
