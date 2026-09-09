import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import 'press.dart';

enum ButtonVariant { primary, outline }

/// The one button, and it is the same object in every room: one 16px corner,
/// one blue, no lift. If a surface wants a button that looks different, the
/// answer is a variant here, never a local override.
class GkButton extends StatelessWidget {
  const GkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.disabled = false,
    this.busy = false,
    this.wide = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;

  /// "Not available" — dimmed and refusing presses.
  final bool disabled;

  /// "Already going" — a spinner in place of the label.
  final bool busy;

  /// The create panel stacks two full-width 44px buttons; the default is the
  /// 34px inline control.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final inert = disabled || busy;
    final outline = variant == ButtonVariant.outline;
    final ink = outline ? Ds.soft : Ds.accent;

    return Press(
      onPressed: onPressed,
      enabled: !inert,
      semanticLabel: label,
      builder: (context, pressed) => AnimatedContainer(
        duration: DsMotion.duration,
        height: wide ? 44 : DsGeom.ctl,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DsGeom.radius),
          border: Border.all(
            color: outline
                ? (pressed ? Ds.edgeHi : Ds.edge)
                : (pressed ? Ds.accent : Ds.accentMix(55)),
          ),
          color: outline
              ? (pressed ? Ds.veil : const Color(0x00000000))
              : Ds.accentMix(pressed ? 20 : 12),
        ),
        child: Opacity(
          opacity: disabled ? 0.45 : 1,
          child: Center(
            child: busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ink),
                  )
                : Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsStyle.ui(
                      DsText.ui,
                      color: ink,
                      weight: FontWeight.w600,
                      tracking: DsTracking.control,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
