import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

/// A failed turn's message, above the composer. Tap to dismiss.
class ErrorBar extends StatelessWidget {
  const ErrorBar({super.key, required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onDismiss,
        semanticLabel: 'Dismiss error',
        builder: (context, pressed) => Container(
          margin: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Ds.destructive.withValues(alpha: pressed ? 0.14 : 0.08),
            border: Border.all(color: Ds.destructive.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: UiText(message, step: DsText.ui, color: Ds.destructive),
        ),
      );
}
