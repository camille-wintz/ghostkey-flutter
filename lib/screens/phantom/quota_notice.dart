import 'package:flutter/widgets.dart';

import '../../core/dates.dart';
import '../../server/dto/billing.dart';
import '../../ui/notice_modal.dart';

/// The 402 face: which counter ran out and when it comes back. No sell —
/// mobile reports and never sells, so the one button only dismisses.
///
/// `snapshot` is the counter as the cached quota read has it, for its label
/// and reset; `refused` is the 402 body when the server refused, whose
/// numbers beat the snapshot's — the snapshot may be the stale one that let
/// the send through.
Future<void> showQuotaNotice(
  BuildContext context, {
  required FeatureQuota? snapshot,
  required QuotaExceeded? refused,
}) {
  final label = (refused?.label ?? snapshot?.label ?? 'chat messages').toLowerCase();
  final allowance = refused?.allowance ?? snapshot?.allowance;
  final periodEnd = refused?.periodEnd ?? snapshot?.periodEnd;
  final weekly = snapshot == null || snapshot.cadence == QuotaCadence.weekly;
  final window = weekly ? 'this week' : 'this period';
  final resets = periodEnd == null || periodEnd.isEmpty ? '' : ' — resets ${formatBillingDate(periodEnd)}';

  final title = switch (allowance) {
    0 => "${_capitalize(label)} aren't included on your plan",
    null => "You've used everything included for $label $window",
    final n => "You've used your $n $label $window",
  };

  return showNoticeModal(
    context,
    eyebrow: 'Allowance spent',
    title: title,
    action: 'Got it',
    children: [
      NoticeText(
        allowance == 0
            ? 'Your plan follows your account rather than this phone, and Account always says which one you are on.'
            : 'The count starts again$resets. Your plan follows your account rather than this phone, and Account always says which one you are on.',
      ),
    ],
  );
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
