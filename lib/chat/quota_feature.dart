import '../server/dto/billing.dart';
import 'models.dart';

/// Which counter a send is gated on, and whether it is already spent.
class ChatQuotaFeature {
  const ChatQuotaFeature({required this.feature, required this.exhausted});
  final String feature;
  final bool exhausted;
}

/// A chat message is paid out of the line that gates [chatQuotaFeature]: the
/// plan's weekly credits since 2026-09-30, charged per model call, so every
/// model draws on the same line and none has a counter of its own. The chat
/// is admitted while any credit is left. A plan that holds the chat unlimited
/// has no pool, and gates nothing. An absent snapshot gates nothing either:
/// the server's 402 is the one gate that must exist, and it re-derives this.
ChatQuotaFeature chatQuotaFor(QuotaSnapshot? snapshot) {
  final line = snapshot?.lineFor(chatQuotaFeature);
  return ChatQuotaFeature(
    feature: line?.feature ?? chatQuotaFeature,
    exhausted: line != null && !line.unlimited && line.remaining == 0,
  );
}

/// "140 of 190 credits left this week" — the line that gates the feature
/// (read it with [QuotaSnapshot.lineFor]); null when unlimited or unknown.
String? quotaLine(FeatureQuota? q) {
  if (q == null || q.unlimited) return null;
  final remaining = q.remaining;
  final allowance = q.allowance;
  if (remaining == null || allowance == null) return null;
  final of = q.unit == QuotaUnit.credits ? formatQuantity(allowance, q.unit) : '$allowance ${q.label.toLowerCase()}';
  return '$remaining of $of left ${q.cadence.window}';
}
