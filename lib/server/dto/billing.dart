import 'json.dart';

/// The plan ladder, cheapest first. Mirrors the contract's `Plan`.
enum Plan {
  free,
  basic,
  standard,
  pro;

  static Plan fromWire(String? value) => switch (value) {
        'basic' => Plan.basic,
        'standard' => Plan.standard,
        'pro' => Plan.pro,
        _ => Plan.free,
      };

  String get displayName => switch (this) {
        Plan.free => 'Free',
        Plan.basic => 'Basic',
        Plan.standard => 'Standard',
        Plan.pro => 'Pro',
      };
}

/// A plan handed out without billing — by an operator (`comp`) or by the
/// system at signup (`welcome`, the welcome week).
class PlanGrant {
  const PlanGrant({
    required this.plan,
    required this.kind,
    required this.expiresAt,
    required this.note,
  });

  final Plan plan;
  final String kind;

  /// Null means open-ended — it lasts until someone revokes it.
  final String? expiresAt;
  final String? note;

  bool get isWelcome => kind == 'welcome';
  bool get isComp => kind == 'comp';

  /// Has this grant run out? Distinct from "revoked", which has no expiry.
  bool get hasExpired {
    final at = expiresAt;
    if (at == null) return false;
    final parsed = DateTime.tryParse(at);
    return parsed != null && !parsed.isAfter(DateTime.now());
  }

  static PlanGrant fromJson(Json json) => PlanGrant(
        plan: Plan.fromWire(json['plan'] as String?),
        kind: asString(json['kind']),
        expiresAt: json['expires_at'] as String?,
        note: json['note'] as String?,
      );
}

/// The Stripe subscription as the account screen needs it.
class SubscriptionRecord {
  const SubscriptionRecord({
    required this.plan,
    required this.status,
    required this.cancelAtPeriodEnd,
    required this.currentPeriodEnd,
  });

  final Plan plan;
  final String status;
  final bool cancelAtPeriodEnd;
  final String currentPeriodEnd;

  static SubscriptionRecord fromJson(Json json) => SubscriptionRecord(
        plan: Plan.fromWire(json['plan'] as String?),
        status: asString(json['status']),
        cancelAtPeriodEnd: asBool(json['cancel_at_period_end']),
        currentPeriodEnd: asString(json['current_period_end']),
      );
}

/// GET /api/billing/subscription. `plan` is the entitlement in force.
class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.plan,
    required this.subscription,
    required this.grant,
    required this.previousGrant,
  });

  final Plan plan;
  final SubscriptionRecord? subscription;
  final PlanGrant? grant;

  /// The newest grant that has *ended* — the only way to tell a lapsed
  /// welcome week from an account that never had one.
  final PlanGrant? previousGrant;

  static SubscriptionSnapshot fromJson(Json json) => SubscriptionSnapshot(
        plan: Plan.fromWire(json['plan'] as String?),
        subscription: json['subscription'] == null
            ? null
            : SubscriptionRecord.fromJson(asJson(json['subscription'])),
        grant: json['grant'] == null ? null : PlanGrant.fromJson(asJson(json['grant'])),
        previousGrant: json['previous_grant'] == null
            ? null
            : PlanGrant.fromJson(asJson(json['previous_grant'])),
      );
}

/// One surface and whether this plan reaches it.
class Capability {
  const Capability({
    required this.id,
    required this.label,
    required this.granted,
    required this.requiredPlan,
  });

  final String id;
  final String label;
  final bool granted;
  final Plan requiredPlan;

  static Capability fromJson(Json json) => Capability(
        id: asString(json['id']),
        label: asString(json['label']),
        granted: asBool(json['granted']),
        requiredPlan: Plan.fromWire(json['required_plan'] as String?),
      );
}

/// GET /api/billing/access — cosmetic by contract: every lock it feeds is
/// enforced again by the surface that does the work.
class AccessSnapshot {
  const AccessSnapshot({required this.plan, required this.capabilities});
  final Plan plan;
  final List<Capability> capabilities;

  static AccessSnapshot fromJson(Json json) => AccessSnapshot(
        plan: Plan.fromWire(json['plan'] as String?),
        capabilities: asJsonList(json['capabilities']).map(Capability.fromJson).toList(),
      );
}

enum QuotaCadence {
  billing,
  weekly;

  static QuotaCadence fromWire(String? value) =>
      value == 'weekly' ? QuotaCadence.weekly : QuotaCadence.billing;
}

/// One counted feature's standing. Numbers are null when `unlimited`.
class FeatureQuota {
  const FeatureQuota({
    required this.feature,
    required this.label,
    required this.cadence,
    required this.periodEnd,
    required this.unlimited,
    required this.allowance,
    required this.used,
    required this.remaining,
  });

  final String feature;
  final String label;
  final QuotaCadence cadence;
  final String periodEnd;
  final bool unlimited;
  final int? allowance;
  final int used;
  final int? remaining;

  static FeatureQuota fromJson(Json json) => FeatureQuota(
        feature: asString(json['feature']),
        label: asString(json['label']),
        cadence: QuotaCadence.fromWire(json['cadence'] as String?),
        periodEnd: asString(json['period_end']),
        unlimited: asBool(json['unlimited']),
        allowance: json['allowance'] as int?,
        used: asInt(json['used']),
        remaining: json['remaining'] as int?,
      );
}

/// GET /api/billing/quota.
class QuotaSnapshot {
  const QuotaSnapshot({required this.plan, required this.periodEnd, required this.features});
  final Plan plan;
  final String periodEnd;
  final List<FeatureQuota> features;

  FeatureQuota? feature(String id) {
    for (final f in features) {
      if (f.feature == id) return f;
    }
    return null;
  }

  static QuotaSnapshot fromJson(Json json) => QuotaSnapshot(
        plan: Plan.fromWire(json['plan'] as String?),
        periodEnd: asString(json['period_end']),
        features: asJsonList(json['features']).map(FeatureQuota.fromJson).toList(),
      );
}

/// The 402 `quota_exceeded` body: which counter refused, and when it resets.
class QuotaExceeded {
  const QuotaExceeded({
    required this.feature,
    required this.label,
    required this.plan,
    required this.allowance,
    required this.used,
    required this.periodEnd,
    required this.upgradePlan,
    required this.upgradeAllowance,
  });

  final String feature;
  final String label;
  final Plan plan;
  final int? allowance;
  final int used;
  final String periodEnd;
  final Plan? upgradePlan;
  final int? upgradeAllowance;

  static QuotaExceeded fromJson(Json json) => QuotaExceeded(
        feature: asString(json['feature']),
        label: asString(json['label']),
        plan: Plan.fromWire(json['plan'] as String?),
        allowance: json['allowance'] as int?,
        used: asInt(json['used']),
        periodEnd: asString(json['period_end']),
        upgradePlan: json['upgrade_plan'] == null ? null : Plan.fromWire(json['upgrade_plan'] as String?),
        upgradeAllowance: json['upgrade_allowance'] as int?,
      );
}

/// One rung and what it costs. `amount` is minor units as Stripe reports them
/// and null means **unknown, not free**.
class PlanPrice {
  const PlanPrice({required this.plan, required this.amount, required this.currency, required this.interval});
  final Plan plan;
  final int? amount;
  final String? currency;
  final String? interval;

  static PlanPrice fromJson(Json json) => PlanPrice(
        plan: Plan.fromWire(json['plan'] as String?),
        amount: json['amount'] as int?,
        currency: json['currency'] as String?,
        interval: json['interval'] as String?,
      );
}

class PlanCatalog {
  const PlanCatalog({required this.currency, required this.plans});
  final String? currency;
  final List<PlanPrice> plans;

  static PlanCatalog fromJson(Json json) => PlanCatalog(
        currency: json['currency'] as String?,
        plans: asJsonList(json['plans']).map(PlanPrice.fromJson).toList(),
      );
}
