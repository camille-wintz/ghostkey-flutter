import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../ui/button.dart';

/// The board before it has rows: loading the stored plan, seeding one from
/// the manuscript, or reporting that the seed didn't land. Never a choice —
/// the board fills itself, so the only button here is a retry.
class PlanBoardStatus extends StatelessWidget {
  const PlanBoardStatus({super.key, required this.message, this.onRetry});
  final String message;

  /// Present when the board gave up rather than is working: the spinner
  /// becomes the one way out.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onRetry == null) ...[
                    SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.5, color: Ds.low)),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(message, textAlign: TextAlign.center, style: DsStyle.ui(DsText.ui, color: Ds.low)),
                  ),
                ],
              ),
              if (onRetry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: GkButton(label: 'Try again', variant: ButtonVariant.outline, onPressed: onRetry),
                ),
            ],
          ),
        ),
      );
}
