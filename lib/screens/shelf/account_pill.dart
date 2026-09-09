import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../ds/tokens.dart';
import '../../server/providers.dart';
import '../../ui/press.dart';

/// The account affordance, and Home's only piece of chrome: the email IS the
/// way in. Sign-out lives inside the screen it opens, not a few pixels from
/// it, because that is a bad place for the irreversible one.
class AccountPill extends ConsumerWidget {
  const AccountPill({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final access = ref.watch(accessProvider).value;
    if (user == null || user.email.isEmpty) return const SizedBox.shrink();

    final badge = !user.emailVerified
        ? ('Unverified', Ds.attention)
        : access != null
            ? (access.plan.displayName, Ds.low)
            : null;

    return Press(
      onPressed: onPressed,
      semanticLabel: 'Account and billing',
      builder: (context, pressed) => AnimatedContainer(
        duration: DsMotion.duration,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: pressed ? Ds.veilHi : Ds.veil,
          border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radiusRound),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsStyle.ui(DsText.eyebrow, color: Ds.soft),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Text(
                badge.$1.toUpperCase(),
                style: DsStyle.ui(const DsStep(9, 12), color: badge.$2, weight: FontWeight.w600, tracking: DsTracking.pill),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
