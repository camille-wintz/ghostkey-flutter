import 'package:flutter/material.dart';

import '../../access/web_account.dart';
import '../../core/dates.dart';
import '../../ds/tokens.dart';
import '../../server/dto/billing.dart';
import '../../ui/notice_modal.dart';
import '../../ui/press.dart';

/// The 402 face, for every room: which counter ran out, how much of it was
/// used, when it comes back, and the way to the website where the plan is
/// managed. The link is a pointer, not a sell — mobile reports and never
/// sells, so the one button only dismisses.
///
/// `snapshot` is the counter as the cached quota read has it, for its cadence
/// and extras; `refused` is the 402 body when the server refused, whose
/// numbers beat the snapshot's — the snapshot may be the stale one that let
/// the call through.
Future<void> showQuotaNotice(
  BuildContext context, {
  required FeatureQuota? snapshot,
  required QuotaExceeded? refused,
}) {
  final label = (refused?.label ?? snapshot?.label ?? 'this feature')
      .toLowerCase();
  final unit = refused?.unit ?? snapshot?.unit ?? QuotaUnit.runs;
  final allowance = refused?.allowance ?? snapshot?.allowance;
  final used = refused?.used ?? snapshot?.used;
  final periodEnd = refused?.periodEnd ?? snapshot?.periodEnd ?? '';
  final window = (snapshot?.cadence ?? QuotaCadence.weekly).window;

  final title = switch (allowance) {
    0 => "${_capitalize(label)} aren't included on your plan",
    _ => "You've used up your $label $window",
  };
  final resets = formatBillingDate(periodEnd);

  return showNoticeModal(
    context,
    eyebrow: 'Quota used up',
    title: title,
    action: 'Got it',
    children: [
      if (allowance != null && allowance > 0 && used != null)
        _QuotaFacts(
          label: refused?.label ?? snapshot?.label ?? 'Allowance',
          used: formatQuantity(used, unit),
          allowance: formatQuantity(allowance, unit),
          extras: (snapshot?.extras ?? 0) > 0
              ? formatQuantity(snapshot!.extras, unit)
              : null,
          resets: resets.isEmpty ? null : 'Resets on $resets',
        ),
      const NoticeText(
        'Your plan follows your account rather than this phone.',
      ),
      const _ManageLink(),
    ],
  );
}

/// The counter as the account screen meters it: name, used of included, a
/// full bar, and the day it resets.
class _QuotaFacts extends StatelessWidget {
  const _QuotaFacts({
    required this.label,
    required this.used,
    required this.allowance,
    required this.extras,
    required this.resets,
  });

  final String label;
  final String used;
  final String allowance;
  final String? extras;
  final String? resets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Ds.void_,
        border: Border.all(color: Ds.edge),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: DsStyle.ui(DsText.ui, color: Ds.hi)),
              ),
              Text(
                extras == null
                    ? '$used / $allowance'
                    : '$used / $allowance · $extras bought',
                style: DsStyle.ui(
                  DsText.ui,
                  color: Ds.mid,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(height: 4, color: Ds.accent),
          ),
          if (resets case final resets?) ...[
            const SizedBox(height: 8),
            Text(resets, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
          ],
        ],
      ),
    );
  }
}

class _ManageLink extends StatelessWidget {
  const _ManageLink();

  @override
  Widget build(BuildContext context) {
    return Press(
      onPressed: () => openWebAccount(context),
      semanticLabel: 'Manage your account options on ghost-key.app',
      builder: (context, pressed) => Text.rich(
        TextSpan(
          style: DsStyle.ui(DsText.body, color: Ds.mid),
          children: [
            const TextSpan(text: 'Manage your account options '),
            TextSpan(
              text: 'here',
              style: TextStyle(
                color: pressed ? Ds.hi : Ds.accent,
                decoration: TextDecoration.underline,
                decorationColor: Ds.accent,
              ),
            ),
            const TextSpan(text: ', on ghost-key.app.'),
          ],
        ),
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
