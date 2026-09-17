import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';

/// Under a finished report: the way to read the book again, and what it
/// costs this week.
class RunAgain extends StatelessWidget {
  const RunAgain({super.key, required this.label, required this.onRun, this.locked = false, this.quota});
  final String label;
  final VoidCallback onRun;
  final bool locked;
  final String? quota;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            GkButton(
              label: label,
              variant: ButtonVariant.outline,
              onPressed: onRun,
              leading: Icon(locked ? LucideIcons.lock : LucideIcons.refreshCw, size: 14, color: Ds.mid),
            ),
            if (quota case final quota?) ...[
              const SizedBox(height: 10),
              Text(quota, textAlign: TextAlign.center, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
            ],
          ],
        ),
      );
}
