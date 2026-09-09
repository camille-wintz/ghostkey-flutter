import 'package:flutter/widgets.dart';

import '../../access/plans.dart';
import '../../chat/refusals.dart';
import '../../ui/notice_modal.dart';

/// "`Model` is part of `Plan`" — a locked picker row, or a 403 from a send.
/// Nothing to buy: mobile reports and never sells.
Future<void> showPlanNotice(BuildContext context, PlanDenied denied) {
  final what = denied.what;
  final plan = denied.requiredPlan == null ? null : planName(denied.requiredPlan!);
  return showNoticeModal(
    context,
    eyebrow: 'Not on your plan',
    title: plan != null ? '$what is part of $plan' : '$what is part of a higher plan',
    action: 'Got it',
    children: [
      NoticeText(
        plan != null
            ? '$plan and the plans above it open $what. Your plan follows your account rather than this phone, and Account always says which one you are on.'
            : 'A higher plan opens $what. Your plan follows your account rather than this phone, and Account always says which one you are on.',
      ),
    ],
  );
}
