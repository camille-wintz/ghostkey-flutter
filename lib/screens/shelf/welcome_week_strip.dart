import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../server/providers.dart';

/// The one place the welcome week stays visible while it runs: a quiet line
/// on Home with the rung and the days left. Only a clock — mobile has
/// nothing to sell. Gone the moment a subscription exists in any state.
class WelcomeWeekStrip extends ConsumerWidget {
  const WelcomeWeekStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(subscriptionProvider).value;
    final grant = snapshot?.grant;
    if (snapshot == null || grant == null || !grant.isWelcome || snapshot.subscription != null) {
      return const SizedBox.shrink();
    }
    final clock = daysLeftLabel(grant.expiresAt);
    final expires = grant.expiresAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Ds.panel,
        border: Border.all(color: Ds.edge),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.sparkles, size: 15, color: Ds.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your free week of ${planName(grant.plan)}${clock != null ? ' — $clock' : ''}',
                  style: DsStyle.ui(DsText.ui, color: Ds.soft, weight: FontWeight.w500),
                ),
                if (expires != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Everything is open until ${formatBillingDate(expires)}.',
                      style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
