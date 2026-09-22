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
