import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ds/tokens.dart';
import 'press.dart';

/// The house bottom sheet: the page stays visible behind it, because what
/// the author is answering came from the page. The grab bar drags it away.
///
/// Sized to its content up to `maxHeightFraction` of the screen. Everything
/// under the header scrolls; the header and the bar are the drag handle.
Future<T?> showGkSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context) builder,
  Widget? header,
  double maxHeightFraction = 0.78,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    barrierColor: const Color(0x80000000),
    useSafeArea: true,
    builder: (context) => _SheetShell(
      maxHeightFraction: maxHeightFraction,
      header: header,
      child: builder(context),
    ),
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.maxHeightFraction, required this.child, this.header});
  final double maxHeightFraction;
  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFraction;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border(top: BorderSide(color: Ds.edgeHi)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(DsGeom.radius)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Ds.edgeHi,
                    borderRadius: BorderRadius.circular(DsGeom.radiusRound),
                  ),
                ),
              ),
              ?header,
              Flexible(child: child),
            ],
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
