import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ds/tokens.dart';
import 'press.dart';

/// The house bottom sheet: the page stays visible behind it, because what
/// the author is answering came from the page. The grab bar drags it away.
///
/// Sized to its content up to `maxHeightFraction` of the screen. Everything
/// under the header scrolls; the header and the bar are the drag handle.
///
/// A sheet that must sometimes refuse to close (it owns work it has to be
/// there to finish) holds a `PopScope` in its body. The scrim tap, the back
/// button and the drag all ask the route, so the drag is refused with them
/// and the sheet springs back.
Future<T?> showGkSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context) builder,
  Widget? header,
  double maxHeightFraction = 0.78,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // The shell drags itself: the route's own drag pops without asking.
    enableDrag: false,
    backgroundColor: const Color(0x00000000),
    barrierColor: const Color(0x80000000),
    useSafeArea: true,
    builder: (context) => _SheetShell(maxHeightFraction: maxHeightFraction, header: header, child: builder(context)),
  );
}

class _SheetShell extends StatefulWidget {
  const _SheetShell({required this.maxHeightFraction, required this.child, this.header});
  final double maxHeightFraction;
  final Widget child;
  final Widget? header;

  @override
  State<_SheetShell> createState() => _SheetShellState();
}

class _SheetShellState extends State<_SheetShell> with SingleTickerProviderStateMixin {
  // How far down the author has pulled the sheet, in pixels.
  late final AnimationController _drag = AnimationController.unbounded(vsync: this);
  bool _closing = false;

  // Past a third of its height, or flicked, and the sheet goes.
  static const _closeFraction = 1 / 3;
  static const _flingVelocity = 700.0;

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_closing) return;
    _drag.value = (_drag.value + details.delta.dy).clamp(0.0, double.infinity);
  }

  Future<void> _onEnd(DragEndDetails details) async {
    if (_closing) return;
    final height = context.size?.height ?? 0;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final goes = velocity > _flingVelocity || (velocity > -_flingVelocity && _drag.value > height * _closeFraction);
    if (goes) {
      _closing = true;
      // The route slides the sheet the rest of the way from where it is.
      final popped = await Navigator.of(context).maybePop();
      if (popped || !mounted) return;
      _closing = false;
    }
    await _drag.animateTo(0, duration: DsMotion.screenIn, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * widget.maxHeightFraction;
    final handle = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onUpdate,
      onVerticalDragEnd: _onEnd,
      onVerticalDragCancel: () => _onEnd(DragEndDetails()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A full-width strip a thumb can find; the bar is only the sign of it.
          Container(
            width: double.infinity,
            height: 24,
            alignment: Alignment.center,
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Ds.edgeHi, borderRadius: BorderRadius.circular(DsGeom.radiusRound)),
            ),
          ),
          ?widget.header,
        ],
      ),
    );
    return AnimatedBuilder(
      animation: _drag,
      builder: (context, child) => Transform.translate(offset: Offset(0, _drag.value), child: child),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Ds.panel,
            border: Border(top: BorderSide(color: Ds.edgeHi)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(DsGeom.radius)),
          ),
          // The keyboard when it is up, the system's button bar when it is not:
          // edge-to-edge, the panel runs under the bar and its last row must not.
          // Flutter zeroes the padding while the insets cover it, so the sum
          // never counts the bar twice.
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                handle,
                Flexible(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sheet's title row: the way back, the name of what is showing, the way
/// out.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.eyebrow, this.trailing, this.onBack, required this.onClose});
  final String eyebrow;
  final String? trailing;
  final VoidCallback? onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DsGeom.row,
      child: Row(
        children: [
          if (onBack != null)
            _RowButton(icon: LucideIcons.chevronLeft, label: 'Back', onPressed: onBack!)
          else
            const SizedBox(width: 20),
          Expanded(
            child: Text(
              '${eyebrow.toUpperCase()}${trailing != null ? '  $trailing' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsStyle.eyebrow(),
            ),
          ),
          _RowButton(icon: LucideIcons.x, label: 'Close', onPressed: onClose),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
    onPressed: onPressed,
    semanticLabel: label,
    builder: (context, pressed) => Container(
      width: DsGeom.row,
      height: DsGeom.row,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pressed ? Ds.veil : const Color(0x00000000),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Icon(icon, size: 17, color: Ds.mid),
    ),
  );
}
