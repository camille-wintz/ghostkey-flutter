import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// The bar's height above the keyboard, safe area excluded. The page keeps
/// the caret clear of it.
const double formatBarHeight = 48;

/// Which emphasis the caret sits in, for the two buttons' lit state.
typedef FormatActive = ({bool bold, bool italic});

/// B · I · mic · camera — and the word count at the far end, so it is in
/// reach while the title block has stepped down out of the way. Pinned above
/// the keyboard by the page; the active state and the count arrive as
/// listenables so a keystroke redraws two glyphs and nothing else.
class FormatBar extends StatelessWidget {
  const FormatBar({
    super.key,
    required this.active,
    required this.words,
    required this.onBold,
    required this.onItalic,
    required this.onMic,
    required this.onCamera,
    this.bottomInset = 0,
  });

  final ValueListenable<FormatActive> active;
  final ValueListenable<int> words;
  final VoidCallback onBold;
  final VoidCallback onItalic;

  /// Null when no launcher is wired: the button draws dimmed.
  final VoidCallback? onMic;
  final VoidCallback? onCamera;

  /// Safe-area padding below the tools, so the bar clears the system
  /// navigation bar when it rests at the bottom of an edge-to-edge screen.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: formatBarHeight + bottomInset,
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
      decoration: BoxDecoration(
        color: Ds.panel,
        border: Border(top: BorderSide(color: Ds.edge)),
      ),
      child: ValueListenableBuilder<FormatActive>(
        valueListenable: active,
        builder: (context, state, _) => Row(
          children: [
            _Tool(
              onPressed: onBold,
              on: state.bold,
              label: 'Bold',
              child: Text(
                'B',
                style: TextStyle(
                  fontFamily: DsFonts.prose,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: state.bold ? Ds.accent : Ds.mid,
                ),
              ),
            ),
            const SizedBox(width: 4),
            _Tool(
              onPressed: onItalic,
              on: state.italic,
              label: 'Italic',
              child: Text(
                'I',
                style: TextStyle(
                  fontFamily: DsFonts.prose,
                  fontStyle: FontStyle.italic,
                  fontSize: 17,
                  color: state.italic ? Ds.accent : Ds.mid,
                ),
              ),
            ),
            const SizedBox(width: 4),
            _Tool(
              onPressed: onMic,
              label: 'Dictate',
              child: Icon(LucideIcons.mic, size: 17, color: Ds.mid),
            ),
            const SizedBox(width: 4),
            _Tool(
              onPressed: onCamera,
              label: 'Scan a page',
              child: Icon(LucideIcons.camera, size: 17, color: Ds.mid),
            ),
            const Spacer(),
            ValueListenableBuilder<int>(
              valueListenable: words,
              builder: (context, count, _) => Text(
                '${formatWords(count)} words',
                style: DsStyle.ui(DsText.ui, color: Ds.mid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.child, required this.onPressed, required this.label, this.on = false});
  final Widget child;
  final VoidCallback? onPressed;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed) => Opacity(
          opacity: onPressed == null ? 0.35 : 1,
          child: Container(
            width: 38,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DsGeom.radius),
              color: on
                  ? Ds.accentMix(12)
                  : pressed
                      ? Ds.veil
                      : const Color(0x00000000),
            ),
            child: child,
          ),
        ),
      );
}
