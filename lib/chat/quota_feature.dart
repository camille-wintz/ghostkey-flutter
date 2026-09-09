import '../server/dto/billing.dart';
import 'models.dart';

/// Which counter a send is gated on, and whether it is already spent.
class ChatQuotaFeature {
  const ChatQuotaFeature({required this.feature, required this.exhausted});
  final String feature;
  final bool exhausted;
}

/// A send spends two allowances: the weekly message counter every chat
/// message draws from, and — for a model counted on its own, Fable today —
/// that model's counter too. The notice can only name one, so it names
/// whichever the snapshot says is the binding one: the model's own counter
/// when *it* is spent, the weekly messages otherwise. The server re-derives
/// both. An absent snapshot gates nothing: the server's 402 is the one gate
/// that must exist.
ChatQuotaFeature chatQuotaFor(QuotaSnapshot? snapshot, String modelId) {
  final modelFeature = modelDef(modelId)?.quota;
  final modelQuota = modelFeature == null ? null : snapshot?.feature(modelFeature);
  final chatQuota = snapshot?.feature(chatQuotaFeature);
  final modelExhausted = modelFeature != null && modelQuota?.remaining == 0;
  return ChatQuotaFeature(
    feature: modelExhausted ? modelFeature : chatQuotaFeature,
    exhausted: modelExhausted || chatQuota?.remaining == 0,
  );
}

/// "12 of 15 chat messages left this week" — null when unlimited or unknown.
String? quotaLine(FeatureQuota? q) {
  if (q == null || q.unlimited) return null;
  final remaining = q.remaining;
  final allowance = q.allowance;
  if (remaining == null || allowance == null) return null;
  final window = q.cadence == QuotaCadence.weekly ? 'this week' : 'this period';
  return '$remaining of $allowance ${q.label.toLowerCase()} left $window';
}
