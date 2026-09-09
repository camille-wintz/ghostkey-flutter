import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/plans.dart';
import '../../access/welcome_notices.dart' as store;
import '../../auth/session.dart';
import '../../server/dto/billing.dart';
import '../../server/providers.dart';
import '../../ui/notice_modal.dart';

/// What the week opens, in the author's words, phone first.
const List<String> _opens = [
  'Dictate straight into a chapter — it lands as prose, not a transcript',
  'Photograph a handwritten page and drop the text where you left off',
  'On the web app: continuity checks, comps, and the plotting room',
];

/// The two welcome-week notices, fired at most once each from Home.
///
/// The arrival greeting needs the signup flag AND a live `welcome` grant; the
/// ended notice needs `previous_grant` to be an expired welcome week with no
/// subscription and no live grant, and fires once per account per device.
/// Neither can open while the other is up.
class WelcomeNotices extends ConsumerStatefulWidget {
  const WelcomeNotices({super.key});

  @override
  ConsumerState<WelcomeNotices> createState() => _WelcomeNoticesState();
}

class _WelcomeNoticesState extends ConsumerState<WelcomeNotices> {
  bool _arrived = false;
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    _arrived = store.takeSignupArrival();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(subscriptionProvider).value;
    final account = ref.watch(sessionProvider.select((s) => s.user?.email));
    if (snapshot != null && account != null && !_decided) {
      _decided = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _decide(snapshot, account));
    }
    return const SizedBox.shrink();
  }

  Future<void> _decide(SubscriptionSnapshot snapshot, String account) async {
    if (!mounted) return;
    final grant = snapshot.grant;
    if (_arrived && grant != null && grant.isWelcome) {
      _arrived = false;
      return _welcome(grant);
    }
    final previous = snapshot.previousGrant;
    if (grant != null || snapshot.subscription != null || previous == null || !previous.isWelcome) return;
    if (!previous.hasExpired) return;
    if (await store.hasSeenWeekEnded(account)) return;
    if (!mounted) return;
    // Shown first, remembered second: marking before opening would spend the
    // account's one notice on a screen that then never drew it.
    await _ended(previous);
    await store.markWeekEndedSeen(account);
  }

  Future<void> _welcome(PlanGrant grant) {
    final plan = planName(grant.plan);
    final ends = grant.expiresAt != null ? formatBillingDate(grant.expiresAt!) : null;
    return showNoticeModal(
      context,
      eyebrow: 'Welcome',
      title: 'Your first week is on $plan',
      action: 'Start writing',
      children: [
        NoticeText(
          'Everything is open${ends != null ? ' until $ends' : ''}. '
          'When the week ends you keep everything you made and move to Free.',
        ),
        for (final line in _opens) NoticeBullet(line),
      ],
    );
  }

  Future<void> _ended(PlanGrant ended) {
    final week = planName(ended.plan);
    final on = ended.expiresAt != null ? ' on ${formatBillingDate(ended.expiresAt!)}' : '';
    return showNoticeModal(
      context,
      eyebrow: 'Your free week',
      title: 'Your week of $week ended$on',
      action: 'Keep writing',
      children: const [
        NoticeText(
          "You're on Free now. Your books, your chapters and everything you wrote "
          'are still yours — the editor and the sync carry on exactly as before.',
        ),
        NoticeText(
          'Dictation and photo-to-text have stopped: they are part of every paid '
          'plan, and Free holds none of them.',
        ),
        NoticeText(
          'Your plan follows your account rather than this phone, and Account '
          'always says which one you are on.',
        ),
      ],
    );
  }
}
