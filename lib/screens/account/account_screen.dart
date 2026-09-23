import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/plans.dart';
import '../../access/web_account.dart';
import '../../access/welcome_notices.dart';
import '../../auth/session.dart';
import '../../ds/tokens.dart';
import '../../server/auth/api.dart';
import '../../server/dto/billing.dart';
import '../../server/dto/gift.dart';
import '../../server/errors.dart';
import '../../server/gift/api.dart';
import '../../server/providers.dart';
import '../../ui/field.dart';
import '../../store/active_project.dart';
import '../../ui/button.dart';
import '../../ui/notice_modal.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import 'delete_account_dialog.dart';
import 'verify_email_notice.dart';

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
  bool _deleting = false;

  Future<void> _signOut() async {
    final email = ref.read(sessionProvider).user?.email ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(email),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
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
    await _forgetSession();
  }

  Future<void> _deleteAccount() async {
    final subscription = ref.read(subscriptionProvider).value?.subscription;
    final confirmed = await confirmDeleteAccount(
      context,
      email: ref.read(sessionProvider).user?.email ?? '',
      hasLiveSubscription:
          subscription != null && subscription.status != 'canceled',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await deleteAccount();
    } catch (e) {
      debugPrint('[account] delete failed: $e');
      if (!mounted) return;
      setState(() => _deleting = false);
      await showNoticeModal(
        context,
        eyebrow: 'Something went wrong',
        title: 'Your account wasn\'t deleted',
        action: 'OK',
        children: [NoticeText(messageFor(e))],
      );
      return;
    }
    await _forgetSession();
  }

  /// What this phone holds for the session, gone — shared by signing out and
  /// by deleting the account.
  Future<void> _forgetSession() async {
    // The next account to sign in on this phone is not the one that just
    // registered — an unconsumed arrival flag would greet them with someone
    // else's welcome week.
    clearSignupArrival();
    ref.read(activeProjectProvider.notifier).close();
    clearServerCache(ref);
    await ref.read(sessionProvider.notifier).clearSession();
  }

  Future<void> _manage() => openWebAccount(context);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final snapshot = ref.watch(subscriptionProvider).value;
    final quota = ref.watch(quotaProvider).value;
    final catalog = ref.watch(planCatalogProvider).value;
    final plan = snapshot?.plan;
    final initial = (user?.email ?? '?').trim().isEmpty
        ? '?'
        : (user?.email ?? '?').trim()[0].toUpperCase();

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Ds.edge)),
              ),
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
                      child: Icon(
                        LucideIcons.chevronLeft,
                        size: 18,
                        color: Ds.mid,
                      ),
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
                        child: Text(
                          initial,
                          style: DsStyle.prose(
                            const DsStep(17, 22),
                            color: Ds.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow('Account', color: Ds.accent),
                            const SizedBox(height: 2),
                            UiText(
                              user?.email ?? '—',
                              color: Ds.hi,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Across the header from Sign out at the bottom, so a
                      // thumb reaching for one never lands on the other. Just
                      // the can: a phone has no hover to spell it out on, and
                      // the confirm it opens names what it deletes.
                      Press(
                        onPressed: _deleteAccount,
                        enabled: !_deleting && !_signingOut,
                        semanticLabel: 'Delete account',
                        builder: (context, pressed) => Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Ds.destructive.withValues(
                              alpha: pressed ? 0.2 : 0.12,
                            ),
                            border: Border.all(
                              color: Ds.destructive.withValues(
                                alpha: pressed ? 1 : 0.55,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(DsGeom.radius),
                          ),
                          child: _deleting
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Ds.destructive,
                                  ),
                                )
                              : Icon(
                                  LucideIcons.trash2,
                                  size: 16,
                                  color: Ds.destructive,
                                ),
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
                            UiText(
                              plan != null ? planName(plan) : '—',
                              color: Ds.hi,
                              weight: FontWeight.w600,
                            ),
                          ],
                        ),
                        for (final feature
                            in (quota?.features ?? const <FeatureQuota>[])
                                .where(
                                  (f) => !f.unlimited && f.allowance != null,
                                )) ...[
                          const SizedBox(height: 14),
                          _QuotaMeter(feature: feature),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GkButton(
                    label: 'Manage plan',
                    wide: true,
                    variant: ButtonVariant.outline,
                    onPressed: _manage,
                  ),
                  const SizedBox(height: 20),
                  // Buy one, give one: the free Basic a paid plan came with, the
                  // one this account holds, or the field to enter a friend's
                  // code. The desk keeps it under a Rewards tab; the phone has
                  // one scrolling account, so it is a card in it.
                  const _GiftSection(),
                  const SizedBox(height: 20),
                  const Eyebrow('Plans'),
                  const SizedBox(height: 8),
                  for (final rung
                      in (catalog?.plans ?? const <PlanPrice>[]).where(
                        (r) => r.plan != Plan.free,
                      ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _Rung(rung: rung, current: rung.plan == plan),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Ds.edge)),
                    ),
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
    final fraction = allowance > 0
        ? (feature.used / allowance).clamp(0.0, 1.0)
        : 0.0;
    final used = formatQuantity(feature.used, feature.unit);
    final included = formatQuantity(allowance, feature.unit);
    final resets = feature.cadence == QuotaCadence.weekly
        ? 'Resets weekly — next on ${formatBillingDate(feature.periodEnd)}'
        : 'Resets on ${formatBillingDate(feature.periodEnd)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: UiText(
                feature.label,
                step: DsText.ui,
                color: Ds.soft,
                maxLines: 1,
              ),
            ),
            Text(
              // Bought runs are not in the bar and must not be: they belong to
              // the account rather than to this window, so a full bar with a
              // pack behind it reads as "the included ones are gone".
              feature.extras > 0
                  ? '$used / $included · ${formatQuantity(feature.extras, feature.unit)} bought'
                  : '$used / $included',
              style: DsStyle.ui(
                DsText.ui,
                color: Ds.mid,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
        Text(
          resets,
          style: DsStyle.ui(DsText.eyebrow, color: Ds.low, tracking: 0.6),
        ),
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
    } else if (grant != null && grant.isGift) {
      // A gift's expiry is the giver's next renewal, not an end date worth
      // naming — the sentence is the rule instead.
      line = subscription != null
          ? '${planName(grant.plan)}, a gift from a friend — it runs as long as they keep their plan. Your ${planName(subscription.plan)} subscription continues.'
          : '${planName(grant.plan)}, a gift from a friend — it runs as long as they keep their plan.';
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
    } else if (grant == null &&
        previous != null &&
        previous.isWelcome &&
        previous.hasExpired &&
        previous.expiresAt != null) {
      line =
          'Your free week of ${planName(previous.plan)} ended on ${formatBillingDate(previous.expiresAt!)}.';
    }

    if (line == null) return const SizedBox.shrink();
    return UiText(line, step: DsText.ui, color: Ds.soft);
  }
}

/// The gift plan on the account: what this account can give, what it holds,
/// or the field to take a friend's code. Reads `giftProvider`; the first read
/// after paying mints the code.
class _GiftSection extends ConsumerWidget {
  const _GiftSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gift = ref.watch(giftProvider);
    return gift.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => _GiftCard(
        eyebrow: 'Rewards',
        title: "Couldn't fetch your rewards.",
        sub: 'Try again in a moment.',
      ),
      data: (read) {
        final giving = read.giving;
        final holding = read.holding;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (giving != null) _Giving(giving: giving),
            if (giving != null && holding != null) const SizedBox(height: 8),
            if (holding != null) _Holding(holding: holding),
            if (giving == null && holding == null) const _ClaimGift(),
          ],
        );
      },
    );
  }
}

class _Giving extends StatelessWidget {
  const _Giving({required this.giving});
  final GiftGiving giving;

  @override
  Widget build(BuildContext context) {
    final plan = planName(giving.plan);
    final taken = giving.claimed;
    return _GiftCard(
      eyebrow: 'Your gift',
      title: taken != null
          ? 'You gave $plan to ${taken.by} on ${formatBillingDate(taken.at)}.'
          : 'Give $plan to someone who writes.',
      sub: taken != null
          ? 'It runs as long as your plan does.'
          : giving.active
              ? 'They keep it as long as you keep your plan.'
              : "Your code is paused while you're off a plan — it works again the moment you're back on one.",
      child: taken == null && giving.active ? _GiftShare(giving: giving) : null,
    );
  }
}

class _Holding extends StatelessWidget {
  const _Holding({required this.holding});
  final GiftHolding holding;

  @override
  Widget build(BuildContext context) {
    final plan = planName(holding.plan);
    return _GiftCard(
      eyebrow: 'A gift',
      title: holding.active ? '$plan, a gift from a friend.' : 'The plan behind your gift ended, so yours did too.',
      sub: holding.active
          ? 'It runs as long as they keep their plan.'
          : "You're on Free. It comes back on its own if they return.",
    );
  }
}

/// The code to read out and the link to send, each a tap to copy.
class _GiftShare extends StatefulWidget {
  const _GiftShare({required this.giving});
  final GiftGiving giving;

  @override
  State<_GiftShare> createState() => _GiftShareState();
}

class _GiftShareState extends State<_GiftShare> {
  String? _copied;

  Future<void> _copy(String what, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _copied = what);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted && _copied == what) setState(() => _copied = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.giving.code,
          style: DsStyle.ui(DsText.body, color: Ds.hi).copyWith(
            fontFamily: 'monospace',
            letterSpacing: 3,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GkButton(
                label: _copied == 'code' ? 'Copied' : 'Copy code',
                variant: ButtonVariant.outline,
                onPressed: () => _copy('code', widget.giving.code),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GkButton(
                label: _copied == 'link' ? 'Copied' : 'Copy link',
                variant: ButtonVariant.outline,
                onPressed: () => _copy('link', widget.giving.link),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Nothing to give and nothing held: the one thing to offer is a place to
/// enter a friend's code. Taking one changes the plan, so every billing read
/// is dropped with the gift's.
class _ClaimGift extends ConsumerStatefulWidget {
  const _ClaimGift();

  @override
  ConsumerState<_ClaimGift> createState() => _ClaimGiftState();
}

class _ClaimGiftState extends ConsumerState<_ClaimGift> {
  final _code = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final code = _code.text.trim();
    if (code.isEmpty || _pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await claimGift(code);
      ref
        ..invalidate(giftProvider)
        ..invalidate(subscriptionProvider)
        ..invalidate(accessProvider)
        ..invalidate(quotaProvider);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GiftCard(
      eyebrow: 'Rewards',
      title: 'Have a gift code?',
      sub: 'A friend on a paid plan can give you Basic. Paid plans come with one to give away.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GkField(
            controller: _code,
            placeholder: 'Gift code',
            autocorrect: false,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _claim(),
          ),
          const SizedBox(height: 8),
          GkButton(label: 'Claim', wide: true, busy: _pending, onPressed: _claim),
          if (_error case final error?) ...[
            const SizedBox(height: 8),
            UiText(error, step: DsText.ui, color: Ds.destructive),
          ],
        ],
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.eyebrow, required this.title, required this.sub, this.child});
  final String eyebrow;
  final String title;
  final String sub;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Ds.accentMix(12),
                  border: Border.all(color: Ds.accentMix(55)),
                  borderRadius: BorderRadius.circular(DsGeom.radius),
                ),
                child: Icon(LucideIcons.gift, size: 16, color: Ds.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(eyebrow),
                    const SizedBox(height: 4),
                    UiText(title, step: DsText.ui, color: Ds.hi),
                    const SizedBox(height: 2),
                    UiText(sub, step: DsText.ui, color: Ds.low),
                  ],
                ),
              ),
            ],
          ),
          if (child case final child?) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}
