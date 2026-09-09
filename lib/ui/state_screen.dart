import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import 'press.dart';

/// Full-screen centered placeholder for loading / empty / error states.
class StateScreen extends StatelessWidget {
  const StateScreen({
    super.key,
    required this.message,
    this.detail,
    this.spinner = false,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String message;
  final String? detail;
  final bool spinner;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A quieter second way out, under the main action.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Ds.void_,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent),
              ),
            ),
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Icon(icon, size: 34, color: Ds.faint),
            ),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DsStyle.ui(DsText.body, color: Ds.mid),
          ),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                detail!,
                textAlign: TextAlign.center,
                style: DsStyle.ui(DsText.ui, color: Ds.low),
              ),
            ),
          if (actionLabel != null && onAction != null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Press(
                onPressed: onAction,
                builder: (context, pressed) => Container(
                  height: DsGeom.ctl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pressed ? Ds.veil : const Color(0x00000000),
                    border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
                    borderRadius: BorderRadius.circular(DsGeom.radius),
                  ),
                  child: Text(
                    actionLabel!,
                    style: DsStyle.ui(DsText.ui, color: Ds.accent, weight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          if (secondaryActionLabel != null && onSecondaryAction != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Press(
                onPressed: onSecondaryAction,
                builder: (context, pressed) => Opacity(
                  opacity: pressed ? 0.7 : 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Text(
                      secondaryActionLabel!,
                      style: DsStyle.ui(DsText.ui, color: Ds.mid),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
