import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import 'fab.dart';

/// The '+' fans into Notes & names / Photo / Record over a dimmed page.
///
/// Fills the page's stack. The ✕ lands on the spot the + rests at
/// (`fabBottom` from the screen edge), or opening the fan would drop it into
/// the system nav bar and take the actions down with it.
class AddMenu extends StatefulWidget {
  const AddMenu({
    super.key,
    required this.fabBottom,
    required this.newNames,
    required this.onNames,
    required this.onPhoto,
    required this.onRecord,
    required this.onClose,
  });

  final double fabBottom;

  /// How many names this chapter introduced that the bible has not filed.
  /// Zero draws no badge — the row is still worth reaching, it just has
  /// nothing to announce.
  final int newNames;
  final VoidCallback onNames;

  /// Null when no launcher is wired: the row draws dimmed.
  final VoidCallback? onPhoto;
  final VoidCallback? onRecord;
  final VoidCallback onClose;

  @override
  State<AddMenu> createState() => _AddMenuState();
}

class _AddMenuState extends State<AddMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 360))
    ..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: CurvedAnimation(parent: _in, curve: const Interval(0, 0.4)),
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: Semantics(label: 'Close', button: true, child: const ColoredBox(color: Color(0x8C000000))),
          ),
        ),
        Positioned(
          right: 20,
          bottom: widget.fabBottom + 70,
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Action(
                animation: _in,
                start: 0,
                icon: LucideIcons.bookMarked,
                label: 'Notes & names',
                hint: "this chapter's people and places",
                badge: widget.newNames,
                onPressed: widget.onNames,
              ),
              _Action(
                animation: _in,
                start: 0.12,
                icon: LucideIcons.camera,
                label: 'Photo',
                hint: 'scan your handwriting',
                onPressed: widget.onPhoto,
              ),
              _Action(
                animation: _in,
                start: 0.25,
                icon: LucideIcons.mic,
                label: 'Record',
                hint: 'dictate aloud',
                onPressed: widget.onRecord,
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: widget.fabBottom,
          child: Fab(icon: LucideIcons.x, semanticLabel: 'Close', onPressed: widget.onClose),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.animation,
    required this.start,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onPressed,
    this.badge = 0,
  });

  final Animation<double> animation;
  final double start;
  final IconData icon;
  final String label;
  final String hint;
  final int badge;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: Interval(start, 1, curve: Curves.easeOutBack));
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Interval(start, (start + 0.4).clamp(0, 1))),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(curved),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Press(
            onPressed: onPressed,
            semanticLabel: label,
            builder: (context, pressed) => Opacity(
              opacity: onPressed == null ? 0.4 : 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(DsGeom.radius),
                      border: Border.all(color: Ds.edge),
                      color: Ds.panel,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: DsStyle.ui(DsText.body, color: Ds.hi)),
                            if (badge > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                height: 18,
                                padding: const EdgeInsets.symmetric(horizontal: 7),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(DsGeom.radiusRound),
                                  color: Ds.attentionMix(18),
                                ),
                                child: Text(
                                  '$badge NEW',
                                  style: TextStyle(
                                    fontFamily: DsFonts.ui,
                                    fontSize: 10,
                                    letterSpacing: DsTracking.pill,
                                    color: Ds.attention300,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(hint, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(DsGeom.radius),
                      border: Border.all(color: pressed ? Ds.accentMix(55) : Ds.edgeHi),
                      color: Ds.raise,
                    ),
                    child: Icon(icon, size: 20, color: Ds.soft),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
