import 'package:flutter/widgets.dart';

import '../access/capability.dart';
import '../access/plans.dart';
import 'notice_modal.dart';

/// What a padlocked control says when tapped: which plan opens it, and
/// nothing to buy — mobile reports and never sells. `fallbackLabel` names the
/// feature until the access snapshot has landed with the server's own label.
void explainLock(BuildContext context, CapabilityState state, String fallbackLabel) {
  final plan = state.requiredPlan != null ? planName(state.requiredPlan!) : null;
  final what = state.label ?? fallbackLabel;
  showNoticeModal(
    context,
    eyebrow: 'Not on your plan',
    title: plan != null ? '$what is part of $plan' : '$what is part of a higher plan',
    action: 'Got it',
    children: [NoticeText('${plan ?? 'A higher plan'} opens it.')],
  );
}
