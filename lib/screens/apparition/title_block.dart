import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../ui/room_menu_button.dart';

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
/// The chapters button lives here because this is what it navigates between —
/// there is no bar above to put it in. The empty box opposite it is doing real
/// work: it keeps the title centred on the SCREEN rather than in the space the
/// button left over.
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
    required this.onRename,
    required this.onMenu,
  });

  final String title;
  final ValueListenable<int> words;
  final ValueListenable<bool> saved;

  /// The reader is into the text, so the chrome steps out of the way.
  final ValueListenable<bool> collapsed;
  final ValueChanged<String> onRename;
  final VoidCallback onMenu;

  @override
  State<TitleBlock> createState() => _TitleBlockState();
}

class _TitleBlockState extends State<TitleBlock> {
  late final TextEditingController _draft = TextEditingController(text: widget.title);
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(TitleBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) _draft.text = widget.title;
  }

  void _onFocus() {
    final focused = _focus.hasFocus;
    if (focused == _focused) return;
    setState(() => _focused = focused);
    if (!focused) _commit();
  }

  void _commit() {
    final next = _draft.text.trim();
    if (next.isEmpty || next == widget.title) {
      _draft.text = widget.title;
      return;
    }
    widget.onRename(next);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.collapsed,
      builder: (context, collapsed, _) {
        // A title being RENAMED shows at full size whatever the scroll says —
        // you should be able to see what you are typing.
        final small = collapsed && !_focused;
        return TweenAnimationBuilder<double>(
          tween: Tween(end: small ? 1 : 0),
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
                  RoomMenuButton(onPressed: widget.onMenu, semanticLabel: 'Chapters'),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _draft,
                          focusNode: _focus,
                          maxLines: null,
                          textAlign: TextAlign.center,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          cursorColor: Ds.accent,
                          onSubmitted: (_) => _focus.unfocus(),
                          style: TextStyle(
                            fontFamily: DsFonts.prose,
                            fontWeight: FontWeight.w600,
                            fontSize: fontSize,
                            height: lineHeight / fontSize,
                            color: Ds.hi,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
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
