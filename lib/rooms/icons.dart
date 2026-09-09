import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

// The room marks, 1:1 from the desktop's `shared/components/app-icons/`
// (the same SVG nodes, with `currentColor` resolved to the ink asked for).
// Drawn by flutter_svg from the markup rather than re-traced as paths, so a
// glyph that changes on the design canvas is copied here, not redrawn.

enum RoomMark { apparition, phantom, veil, poltergeist }

const String _apparition = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="miter">
  <g transform="rotate(-14 12 10.5)">
    <path d="M12 1.9 16.6 8.9 12 15.9 7.4 8.9Z"/>
    <path d="M12 8.2V12.7"/>
  </g>
  <path d="M4.2 20.4C6.1 18.2 7.4 21.7 9.4 20.2 11.3 18.8 12.6 21.5 14.6 19.9" stroke-linejoin="round"/>
  <circle cx="17.2" cy="19.1" r="1.05" fill="#fff" stroke="none"/>
</svg>''';

const String _phantom = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="10" r="7"/>
  <path d="M9.2 10.3C10.3 8.8 13.7 8.8 14.8 10.3"/>
  <circle cx="12" cy="11.2" r="1.15" fill="#fff" stroke="none"/>
  <path d="M9.7 16.8 8.4 20.3M14.3 16.8 15.6 20.3M7.4 20.5H16.6"/>
</svg>''';

const String _veil = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round">
  <path d="M2.6 3.2H21.4" stroke-linejoin="miter"/>
  <path d="M4.4 3.6C5.4 9.2 4.8 15.6 3.4 20.8"/>
  <path d="M3.4 20.8C9 21.4 15.6 17 19.4 8.4V3.6"/>
  <path d="M8.6 4.2C9.4 8.8 8.8 13.2 7.4 16.8" stroke-opacity="0.45"/>
  <path d="M11.4 19.6H20.6" stroke-opacity="0.5"/>
  <circle cx="17.2" cy="13.8" r="1.15" fill="#fff" stroke="none"/>
</svg>''';

const String _poltergeist = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="miter">
  <g transform="rotate(-10 11 13)">
    <rect x="5" y="5.6" width="11.8" height="14.4" rx="1.2"/>
    <path d="M8 10H13.8M8 13.2H13.8M8 16.4H11.6"/>
  </g>
  <path d="M19.6 12.4 21.6 11.1M19 16.2 20.7 17" stroke-opacity="0.5"/>
  <circle cx="20.4" cy="6.6" r="1.2" fill="#fff" stroke="none"/>
</svg>''';

String _markupFor(RoomMark mark) => switch (mark) {
      RoomMark.apparition => _apparition,
      RoomMark.phantom => _phantom,
      RoomMark.veil => _veil,
      RoomMark.poltergeist => _poltergeist,
    };

/// One room's mark at the size of its neighbours, in one ink.
class RoomIcon extends StatelessWidget {
  const RoomIcon(this.mark, {super.key, this.size = 24, this.color = const Color(0xFFFFFFFF)});
  final RoomMark mark;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        _markupFor(mark),
        width: size,
        height: size,
        colorFilter: color == const Color(0xFFFFFFFF) ? null : ColorFilter.mode(color, BlendMode.srcIn),
      );
}
