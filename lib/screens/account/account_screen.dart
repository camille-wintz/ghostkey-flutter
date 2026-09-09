import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../access/plans.dart';
import '../../access/welcome_notices.dart';
import '../../auth/session.dart';
import '../../ds/tokens.dart';
import '../../server/auth/api.dart';
import '../../server/dto/billing.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/button.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import 'verify_email_notice.dart';

/// Where an author changes what they pay: the website, not a checkout in the
/// app. A purchase flow that is not Play Billing is what gets a build
/// rejected, so the app reports the plan and never sells it.
const String _webAccountUrl = 'https://ghost-key.app/';

/// The account: who is signed in, what they are on, what is left of it, and
/// the way out. Everything here is read.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  static const route = '/account';

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    final email = ref.read(sessionProvider).user?.email ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(email),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Sign out', style: TextStyle(color: Ds.destructive)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    final token = ref.read(sessionProvider).refreshToken;
    if (token != null) await postSignout(token);
    // The next account to sign in on this phone is not the one that just
    // registered — an unconsumed arrival flag would greet them with someone
    // else's welcome week.
    clearSignupArrival();
    ref.read(activeProjectProvider.notifier).close();
    clearServerCache(ref);
    await ref.read(sessionProvider.notifier).clearSession();
  }

  Future<void> _manage() async {
    final ok = await launchUrl(Uri.parse(_webAccountUrl), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Could not open the browser'),
          content: Text('Go to $_webAccountUrl to change your plan.'),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final snapshot = ref.watch(subscriptionProvider).value;
    final quota = ref.watch(quotaProvider).value;
    final catalog = ref.watch(planCatalogProvider).value;
    final plan = snapshot?.plan;
    final initial = (user?.email ?? '?').trim().isEmpty ? '?' : (user?.email ?? '?').trim()[0].toUpperCase();

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
              child: Row(
                children: [
                  Press(
                    onPressed: () => Navigator.of(context).pop(),
                    semanticLabel: 'Back to home',
                    builder: (context, pressed) => Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: pressed ? Ds.veil : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(DsGeom.radius),
                      ),
                      child: Icon(LucideIcons.chevronLeft, size: 18, color: Ds.mid),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const BrandTitle('Account', size: BrandTitleSize.chrome),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Ds.accentMix(12),
                          border: Border.all(color: Ds.accentMix(55)),
                          shape: BoxShape.circle,
                        ),
                        child: Text(initial, style: DsStyle.prose(const DsStep(17, 22), color: Ds.accent)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow('Account', color: Ds.accent),
                            const SizedBox(height: 2),
                            UiText(user?.email ?? '—', color: Ds.hi, maxLines: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (user != null && !user.emailVerified) ...[
                    VerifyEmailNotice(email: user.email),
                    const SizedBox(height: 20),
                  ],
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Ds.surf,
                      border: Border.all(color: Ds.edge),
                      borderRadius: BorderRadius.circular(DsGeom.radius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Eyebrow('Current plan'),
                                  const SizedBox(height: 4),
                                  _PlanSentence(snapshot: snapshot),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            UiText(plan != null ? planName(plan) : '—', color: Ds.hi, weight: FontWeight.w600),
                          ],
                        ),
                        for (final feature in (quota?.features ?? const <FeatureQuota>[])
                            .where((f) => !f.unlimited && f.allowance != null)) ...[
                          const SizedBox(height: 14),
                          _QuotaMeter(feature: feature),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GkButton(label: 'Manage plan', wide: true, variant: ButtonVariant.outline, onPressed: _manage),
                  const SizedBox(height: 8),
                  UiText(
                    'Opens ghost-key.app in your browser. Your plan follows your account rather than this phone.',
                    step: DsText.eyebrow,
                    color: Ds.low,
                  ),
                  const SizedBox(height: 20),
                  const Eyebrow('Plans'),
                  const SizedBox(height: 8),
                  for (final rung in (catalog?.plans ?? const <PlanPrice>[]).where((r) => r.plan != Plan.free))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _Rung(rung: rung, current: rung.plan == plan),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Ds.edge))),
                    child: Press(
                      onPressed: _signOut,
                      enabled: !_signingOut,
                      builder: (context, pressed) {
                        final tone = _signingOut ? Ds.destructive : Ds.low;
                        return Container(
                          height: 44,
                          margin: const EdgeInsets.only(top: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pressed ? Ds.veil : const Color(0x00000000),
                            borderRadius: BorderRadius.circular(DsGeom.radius),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.logOut, size: 14, color: tone),
                              const SizedBox(width: 8),
                              UiText('Sign out', step: DsText.ui, color: tone),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({required this.rung, required this.current});
  final PlanPrice rung;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final price = formatPrice(rung.amount, rung.currency);
    return Opacity(
      // The rung already in force is dimmed rather than removed: where you
      // are on the ladder is part of what it says.
      opacity: current ? 0.45 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Ds.surf,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            Expanded(child: Eyebrow(planName(rung.plan), color: Ds.soft)),
            if (price != null) ...[
              UiText(price, color: Ds.hi, weight: FontWeight.w600),
              if (rung.interval != null) ...[
                const SizedBox(width: 4),
                UiText('/ ${rung.interval}', step: DsText.ui, color: Ds.mid),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// One counted feature and what is left of it.
class _QuotaMeter extends StatelessWidget {
  const _QuotaMeter({required this.feature});
  final FeatureQuota feature;

  @override
  Widget build(BuildContext context) {
    final allowance = feature.allowance ?? 0;
    final fraction = allowance > 0 ? (feature.used / allowance).clamp(0.0, 1.0) : 0.0;
    final resets = feature.cadence == QuotaCadence.weekly
        ? 'Resets weekly — next on ${formatBillingDate(feature.periodEnd)}'
        : 'Resets on ${formatBillingDate(feature.periodEnd)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: UiText(feature.label, step: DsText.ui, color: Ds.soft, maxLines: 1)),
            Text(
              '${feature.used} / $allowance',
              style: DsStyle.ui(DsText.ui, color: Ds.mid).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(DsGeom.radiusRound),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 3,
            backgroundColor: Ds.edge,
            color: fraction >= 1 ? Ds.attention : Ds.accent,
          ),
        ),
        const SizedBox(height: 7),
        Text(resets, style: DsStyle.ui(DsText.eyebrow, color: Ds.low, tracking: 0.6)),
      ],
    );
  }
}

/// The line under "Current plan" — what put the account where it is, when
/// there is something to say.
class _PlanSentence extends StatelessWidget {
  const _PlanSentence({required this.snapshot});
  final SubscriptionSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    if (s == null) return const SizedBox.shrink();
    final grant = s.grant;
    final previous = s.previousGrant;
    final subscription = s.subscription;
    String? line;

    if (grant != null && grant.isWelcome && subscription == null) {
      final clock = daysLeftLabel(grant.expiresAt);
      line = grant.expiresAt == null
          ? 'Your free week.'
          : 'Your free week — ${clock ?? 'ending'}, until ${formatBillingDate(grant.expiresAt!)}.';
    } else if (grant != null && grant.isComp) {
      line = grant.expiresAt == null
          ? subscription != null
              ? '${planName(grant.plan)} on the house — yours with no end date. Your ${planName(subscription.plan)} subscription continues.'
              : '${planName(grant.plan)} on the house — yours with no end date.'
          : '${planName(grant.plan)} on the house, until ${formatBillingDate(grant.expiresAt!)}.';
    } else if (subscription != null && subscription.cancelAtPeriodEnd) {
      line = 'Ends on ${formatBillingDate(subscription.currentPeriodEnd)}.';
    } else if (subscription != null) {
      line = 'Renews on ${formatBillingDate(subscription.currentPeriodEnd)}.';
    } else if (grant == null && previous != null && previous.isWelcome && previous.hasExpired && previous.expiresAt != null) {
      line = 'Your free week of ${planName(previous.plan)} ended on ${formatBillingDate(previous.expiresAt!)}.';
    }

    if (line == null) return const SizedBox.shrink();
    return UiText(line, step: DsText.ui, color: Ds.soft);
  }
}
