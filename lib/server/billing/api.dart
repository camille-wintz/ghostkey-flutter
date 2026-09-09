import '../client.dart';
import '../dto/billing.dart';

/// What the account is on, and what put it there. Mobile sells nothing, so
/// this is read to say whether the welcome week is running and to notice once
/// when it has run out.
Future<SubscriptionSnapshot> getSubscription() async {
  final res = await apiFetch('/api/billing/subscription');
  return SubscriptionSnapshot.fromJson(res.jsonObject());
}

/// Which surfaces the plan reaches — the whole capability table, denied
/// entries included. Cosmetic by contract.
Future<AccessSnapshot> getAccess() async {
  final res = await apiFetch('/api/billing/access');
  return AccessSnapshot.fromJson(res.jsonObject());
}

/// What remains of each counted feature this period.
Future<QuotaSnapshot> getQuota() async {
  final res = await apiFetch('/api/billing/quota');
  return QuotaSnapshot.fromJson(res.jsonObject());
}

/// What each rung of the ladder costs. The one unauthenticated cloud read.
/// Amounts come from Stripe; there is no fallback table anywhere.
Future<PlanCatalog> getPlanCatalog() async {
  final res = await apiFetch('/api/billing/plans', auth: false);
  return PlanCatalog.fromJson(res.jsonObject());
}
