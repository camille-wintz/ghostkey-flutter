import 'dart:async';

import '../server/dto/billing.dart';
import '../server/errors.dart';

/// A 402 `quota_exceeded`, as a room reports it to the one owner that shows
/// the notice — the app root (`app.dart`). Reporting takes no context, so a
/// job notifier, a ChangeNotifier and a plain function all report the same way.
typedef QuotaRefusalReport = ({String? feature, QuotaExceeded? refused});

final _reports = StreamController<QuotaRefusalReport>.broadcast();

Stream<QuotaRefusalReport> get quotaRefusals => _reports.stream;

/// Report [e] if it is a spent allowance, and say whether it was. A caller
/// that gets `true` leaves its own error line empty: the notice explains it.
bool reportQuotaRefusal(Object? e) {
  if (e is! ServerError || e.code != 'quota_exceeded') return false;
  _reports.add((feature: e.quota?.feature, refused: e.quota));
  return true;
}

/// Report [feature] as spent without a refusal to go with it — a room that
/// read the counter first and did not make the call. [snapshot] is a fresh
/// quota read, whose numbers the notice shows; without one the notice falls
/// back to the cached read. The notice names the line that gates [feature] —
/// the weekly credits for a feature paid out of them — as the server's 402
/// would.
void reportQuotaSpent(String feature, {QuotaSnapshot? snapshot}) {
  final f = snapshot?.lineFor(feature);
  _reports.add((
    feature: f?.feature ?? feature,
    refused: f == null
        ? null
        : QuotaExceeded(
            feature: f.feature,
            label: f.label,
            plan: snapshot!.plan,
            allowance: f.allowance,
            used: f.used,
            periodEnd: f.periodEnd,
            upgradePlan: null,
            upgradeAllowance: null,
            unit: f.unit,
          ),
  ));
}
