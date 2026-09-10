import 'package:flutter/material.dart';

import '../ds/tokens.dart';

/// The margin the panel keeps off the screen's edges.
const double _margin = 10;

/// Air between the control and the panel it unfolded from.
const double _gap = 6;

/// A room's own list, unfolded from the control that opened it.
///
/// It grows out of its anchor rather than arriving from an edge: the chevron
/// under a title is the hinge, so the panel scales up out of that title's own
/// line and fades as it goes, then folds back into it. That is what makes the
/// chevron mean anything — a mark pointing down over a surface that slid in
/// from the left was the tell that the control and the panel were two
/// different ideas wearing one gesture.
///
/// A route rather than an overlay, so Android's back closes the panel before
/// it leaves the room, and the room underneath keeps everything it was
/// holding: nothing about the editor's field or the thread's scroll is rebuilt
/// while the list is open.
Future<T?> showAnchoredPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required String label,

  /// The control it unfolds from, in global coordinates. Null when there is no
  /// control to unfold from — a room with nothing selected opening its own
  /// list — and the panel then grows from the top of the screen instead.
  Rect? anchor,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierLabel: label,
    barrierColor: const Color(0x8C000000),
    transitionDuration: DsMotion.screenIn,
    pageBuilder: (context, _, _) => _Panel(anchor: anchor, child: Builder(builder: builder)),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          // Along the panel's top edge, over the middle of what opened it: the
          // growth reads as coming out of the control, not out of the screen.
          alignment: Alignment(_originX(context, anchor), -1),
          child: child,
        ),
      );
    },
  );
}

/// The anchor's centre as a fraction of the panel's width, in `Alignment`'s
/// -1..1. Centred when there is no anchor.
double _originX(BuildContext context, Rect? anchor) {
  if (anchor == null) return 0;
  final width = MediaQuery.sizeOf(context).width - 2 * _margin;
  if (width <= 0) return 0;
  return (((anchor.center.dx - _margin) / width) * 2 - 1).clamp(-1.0, 1.0);
}

/// Where a control sits on the screen, for a panel to unfold from — null while
/// the control is not mounted, which is the case a caller passes straight on.
Rect? anchorRectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The surface: hung under the anchor and run to the bottom of the screen,
/// because what it holds is a list long enough to need the room.
class _Panel extends StatelessWidget {
  const _Panel({required this.anchor, required this.child});
  final Rect? anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final top = (anchor?.bottom ?? padding.top) + _gap;
    return Padding(
      padding: EdgeInsets.fromLTRB(_margin, top, _margin, _margin + padding.bottom),
      child: Material(
        color: Ds.panel,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DsGeom.radius),
          side: BorderSide(color: Ds.edgeHi),
        ),
        child: child,
      ),
    );
  }
}
