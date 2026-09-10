import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../ui/anchored_panel.dart';
import '../../ui/press.dart';
import '../../ui/room_back_button.dart';

// The save tick and the empty slot that balances it.
const double _markSize = 12;
const double _markSlot = 17;

/// The chapter's name, how long it is, and the way to its neighbours.
///
/// The title is the serif voice at display size — the one place in the room
/// where the app speaks like a book about the book. It is not the manuscript
/// face: the page below is Spectral, and a title in the page's own face would
/// read as the first line of the prose.
///
/// The name is also the way into the chapter list: the chevron beside it is
/// the hinge the list unfolds from, and the name is held to one line so that
/// chevron always has room. It used to be a hamburger in the corner and a
/// title you could type into, which put the room's navigation in the one place
/// a phone reserves for the way back — so leaving Apparition meant opening a
/// drawer and pressing its head, a door behind a door. The corner is the way
/// back now, the title is the list, and renaming a chapter is the list's own
/// row menu, where renaming any *other* chapter already lived.
///
/// The empty box opposite the back chevron is doing real work: it keeps the
/// title centred on the SCREEN rather than in the space the chevron left over.
///
/// The save state is a tick beside the word count and nothing else. A word
/// count that has just moved and no tick beside it *is* the unsaved state, so
/// the mark only has to appear — it never has to say "Saving…" at the writer.
///
/// The block does not scroll — it is the fixed head of the page, and only the
/// prose moves under it — so it steps down instead, on one timed transition
/// between two sizes rather than a size interpolated against the finger.
///
/// It also carries the status bar's inset, and it is the only thing in the
/// room that does: the app draws edge to edge, and this is the topmost thing
/// on the page. A `SafeArea` above it would leave a black strip under the
/// clock; padding it means the block's own fill runs up behind the bar and
/// the chapter's name starts below it.
///
/// The count and the tick come in as listenables and redraw on their own:
/// this block is above the page's field and must not rebuild per keystroke.
class TitleBlock extends StatefulWidget {
  const TitleBlock({
    super.key,
    required this.title,
    required this.words,
    required this.saved,
    required this.collapsed,
    required this.onBack,
    required this.onOpenChapters,
  });

  final String title;
  final ValueListenable<int> words;
  final ValueListenable<bool> saved;

  /// The reader is into the text, so the chrome steps out of the way.
  final ValueListenable<bool> collapsed;
  final VoidCallback onBack;

  /// Open the chapter list, unfolded from the title's own box.
  final void Function(Rect? anchor) onOpenChapters;

  @override
  State<TitleBlock> createState() => _TitleBlockState();
}

class _TitleBlockState extends State<TitleBlock> {
  final GlobalKey _titleKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.collapsed,
      builder: (context, collapsed, _) {
        return TweenAnimationBuilder<double>(
          tween: Tween(end: collapsed ? 1 : 0),
          duration: DsMotion.screenIn,
          curve: Curves.easeOutCubic,
          builder: (context, step, _) {
            double lerp(double a, double b) => a + (b - a) * step;
            final fontSize = lerp(30, 20);
            final lineHeight = lerp(38, DsGeom.row);
            // The count row with the air above it: 8 + the eyebrow's 14px line.
            const countRow = 8 + 14.0;
            final countHeight = lerp(countRow, 0);
            return Container(
              padding: EdgeInsets.fromLTRB(
                8,
                MediaQuery.paddingOf(context).top + lerp(12, 6),
                8,
                lerp(18, 0),
              ),
              decoration: BoxDecoration(
                color: Ds.void_,
                border: Border(bottom: BorderSide(color: collapsed ? Ds.edge : const Color(0x00000000))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoomBackButton(onPressed: widget.onBack, semanticLabel: 'Back to the book'),
                  Expanded(
                    child: Column(
                      children: [
                        Press(
                          key: _titleKey,
                          onPressed: () => widget.onOpenChapters(anchorRectOf(_titleKey)),
                          semanticLabel: '${widget.title}, open the chapter list',
                          builder: (context, pressed) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: pressed ? Ds.veil : const Color(0x00000000),
                              borderRadius: BorderRadius.circular(DsGeom.radius),
                            ),
                            // The name is capped to one line so the chevron
                            // always has room beside it. That cap is what puts
                            // it there: a text allowed to wrap fills its whole
                            // box, so a chevron next to it lands at the far
                            // right with nothing near it, and a chevron set IN
                            // the text is dropped onto a line of its own by the
                            // line breaker. Held to one line the box hugs the
                            // name, and the mark sits against the last letter
                            // whether that is the whole title or an ellipsis.
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: DsFonts.prose,
                                      fontWeight: FontWeight.w600,
                                      fontSize: fontSize,
                                      height: lineHeight / fontSize,
                                      color: Ds.hi,
                                      leadingDistribution: TextLeadingDistribution.even,
                                    ),
                                  ),
                                ),
                                SizedBox(width: lerp(8, 6)),
                                Icon(LucideIcons.chevronDown, size: lerp(21, 16), color: Ds.mid),
                              ],
                            ),
                          ),
                        ),
                        // The tick keeps a slot of its own, matched by an empty
                        // one on the left: the count is centred on the screen
                        // either way, so it does not step sideways when a save
                        // lands. Height as well as opacity: fading alone would
                        // leave the gap it used to fill.
                        ClipRect(
                          child: SizedBox(
                            height: countHeight,
                            child: Opacity(
                              opacity: 1 - step,
                              child: OverflowBox(
                                minHeight: countRow,
                                maxHeight: countRow,
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _CountRow(words: widget.words, saved: widget.saved),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DsGeom.row),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.words, required this.saved});
  final ValueListenable<int> words;
  final ValueListenable<bool> saved;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: _markSlot),
          ValueListenableBuilder<int>(
            valueListenable: words,
            builder: (context, count, _) => Text(
              '${formatWords(count)} WORDS',
              maxLines: 1,
              style: DsStyle.eyebrow(),
            ),
          ),
          SizedBox(
            width: _markSlot,
            child: ValueListenableBuilder<bool>(
              valueListenable: saved,
              builder: (context, isSaved, _) => isSaved
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(label: 'saved', child: Icon(LucideIcons.check, size: _markSize, color: Ds.low)),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      );
}
