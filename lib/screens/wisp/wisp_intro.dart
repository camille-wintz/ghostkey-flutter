import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';

/// A page before its first run: what the run reads and says, and the button
/// that starts it — padlocked when the plan does not open it.
class WispIntro extends StatelessWidget {
  const WispIntro({
    super.key,
    required this.icon,
    required this.blurb,
    required this.action,
    required this.onRun,
    this.locked = false,
    this.disabled = false,
    this.quota,
    this.footnote,
  });

  final IconData icon;
  final String blurb;
  final String action;
  final VoidCallback onRun;
  final bool locked;
  final bool disabled;

  /// "2 of 3 book analyses left this week", when the plan counts.
  final String? quota;

  /// Why the button waits, when it does.
  final String? footnote;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Ds.accentMix(12), borderRadius: BorderRadius.circular(DsGeom.radius)),
              child: Icon(icon, size: 22, color: Ds.accent),
            ),
            const SizedBox(height: 16),
            Text(blurb, textAlign: TextAlign.center, style: DsStyle.prose(DsText.body, color: Ds.soft)),
            const SizedBox(height: 20),
            GkButton(
              label: action,
              onPressed: onRun,
              disabled: disabled,
              leading: locked ? Icon(LucideIcons.lock, size: 14, color: Ds.hi) : null,
            ),
            if (quota case final quota?) ...[
              const SizedBox(height: 12),
              Text(quota, textAlign: TextAlign.center, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
            ],
            if (footnote case final footnote?) ...[
              const SizedBox(height: 12),
              Text(footnote, textAlign: TextAlign.center, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
            ],
          ],
        ),
      );
}
