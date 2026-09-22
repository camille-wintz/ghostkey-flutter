import 'package:flutter/widgets.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../ui/notice_modal.dart';

/// What a locked run says when tapped: which plan opens it, and nothing to
/// buy — mobile reports and never sells.
void explainWispLock(
  BuildContext context,
  CapabilityState state,
  String fallbackLabel,
) {
  final plan = state.requiredPlan != null
      ? planName(state.requiredPlan!)
      : null;
  final what = state.label ?? fallbackLabel;
  showNoticeModal(
    context,
    eyebrow: 'Not on your plan',
    title: plan != null
        ? '$what is part of $plan'
        : '$what is part of a higher plan',
    action: 'Got it',
    children: [NoticeText('${plan ?? 'A higher plan'} opens it.')],
  );
}
