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

/// A plan handed out without billing — by an operator (`comp`), by the
/// system at signup (`welcome`, the welcome week), or by a paying author's
/// gift (`gift`, whose expiry follows the giver's billing period).
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
  bool get isGift => kind == 'gift';

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
  weekly,

  /// Free's chat messages reset every day; the other plans count them weekly.
  daily;

  static QuotaCadence fromWire(String? value) => switch (value) {
        'weekly' => QuotaCadence.weekly,
        'daily' => QuotaCadence.daily,
        _ => QuotaCadence.billing,
      };

  /// "this week" — the window the count runs over, for a sentence.
  String get window => switch (this) {
        QuotaCadence.daily => 'today',
        QuotaCadence.weekly => 'this week',
        QuotaCadence.billing => 'this period',
      };
}

/// What a feature's numbers count. Every counter counts runs except
/// dictation, which counts audio-seconds, and — since 2026-09-30 — the one
/// weekly pool most features are paid out of, which counts credits. A feature
/// paid from the pool keeps its own unit. Anything shown to an author goes
/// through [formatQuantity].
enum QuotaUnit {
  runs,
  seconds,
  credits;

  /// Absent (a server that predates the field) is runs.
  static QuotaUnit fromWire(String? value) => switch (value) {
        'seconds' => QuotaUnit.seconds,
        'credits' => QuotaUnit.credits,
        _ => QuotaUnit.runs,
      };
}

/// One quota number in its unit: runs stay bare, credits say so ("140
/// credits", "1 credit"), seconds read as minutes, floored — "31 min", "1 h",
/// "1 h 20 min". Mirrors the desktop's `formatQuantity`.
String formatQuantity(int n, QuotaUnit unit) {
  if (unit == QuotaUnit.runs) return '$n';
  if (unit == QuotaUnit.credits) return n == 1 ? '1 credit' : '$n credits';
  final minutes = n ~/ 60;
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$minutes min';
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// How much of an allowance is gone, as the meter says it: "3 / 5" on Free,
/// "40% used" on a paid plan. Never rounded to a share the bar contradicts —
/// one spent is at least 1%, and 100% only once it is all gone. Credits say
/// their unit once, at the end — "50 / 190 credits", not "50 credits / 190
/// credits". Mirrors the desktop's `formatUsage`.
String formatUsage(int used, int allowance, QuotaUnit unit, bool asShare) {
  if (!asShare) {
    if (unit == QuotaUnit.credits) return '$used / ${formatQuantity(allowance, unit)}';
    return '${formatQuantity(used, unit)} / ${formatQuantity(allowance, unit)}';
  }
  if (allowance <= 0 || used >= allowance) return '100% used';
  final share = (used / allowance * 100).round().clamp(used > 0 ? 1 : 0, 99);
  return '$share% used';
}

/// One counted feature's standing. Numbers are null when `unlimited`.
///
/// A feature paid out of a pool ([pool] set — `credits`) carries no counts of
/// its own: `allowance` is null, `used` 0, and `remaining` is how much of it
/// the pool's balance would pay for, in the feature's own unit. Its meter,
/// notice and "N left" line are the pool's — [QuotaSnapshot.lineFor].
class FeatureQuota {
  const FeatureQuota({
    required this.feature,
    required this.label,
    required this.cadence,
    required this.periodEnd,
    required this.unlimited,
    required this.allowance,
    required this.used,
    required this.extras,
    required this.remaining,
    this.unit = QuotaUnit.runs,
    this.pool,
    this.price,
  });

  final String feature;
  final String label;
  final QuotaCadence cadence;
  final QuotaUnit unit;
  final String periodEnd;
  final bool unlimited;
  final int? allowance;
  final int used;

  /// Runs bought and not yet spent. They sit outside the window — a top-up pack
  /// does not expire with it — so a meter reading "5 / 5" can still have runs
  /// behind it. Shown beside the bar rather than folded into it.
  ///
  /// Mobile does not sell packs (Play bills digital goods its own way); this is
  /// here so the balance an author bought elsewhere is visible on the phone.
  final int extras;
  final int? remaining;

  /// The counter that pays for this feature on the caller's plan (`credits`),
  /// or null when it is counted on its own or not at all. Absent on a server
  /// that predates the pool, which reads the same as null.
  final String? pool;

  /// What one unit of this feature costs out of [pool], in credits — may be
  /// fractional (dictation is priced per second). Null without a pool.
  final double? price;

  static FeatureQuota fromJson(Json json) => FeatureQuota(
        feature: asString(json['feature']),
        label: asString(json['label']),
        cadence: QuotaCadence.fromWire(json['cadence'] as String?),
        periodEnd: asString(json['period_end']),
        unlimited: asBool(json['unlimited']),
        allowance: json['allowance'] as int?,
        used: asInt(json['used']),
        extras: asInt(json['extras']),
        remaining: json['remaining'] as int?,
        unit: QuotaUnit.fromWire(json['unit'] as String?),
        pool: json['pool'] as String?,
        price: (json['price'] as num?)?.toDouble(),
      );
}

/// GET /api/billing/quota.
class QuotaSnapshot {
  const QuotaSnapshot({required this.plan, required this.periodEnd, required this.features});
  final Plan plan;
  final String periodEnd;
  final List<FeatureQuota> features;

  /// The feature's own entry, exactly as listed. For what a meter, a notice or
  /// an "N left" line should show, read [lineFor].
  FeatureQuota? feature(String id) {
    for (final f in features) {
      if (f.feature == id) return f;
    }
    return null;
  }

  /// The line that gates [id]: its pool's entry when a pool pays for it (the
  /// weekly `credits`), else its own. Falls back to the feature's own entry if
  /// the snapshot names a pool it does not list. Null when neither is here.
  FeatureQuota? lineFor(String id) {
    final own = feature(id);
    final pool = own?.pool;
    if (pool == null) return own;
    return feature(pool) ?? own;
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
    this.unit = QuotaUnit.runs,
  });

  final String feature;
  final String label;
  final Plan plan;
  final QuotaUnit unit;
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
        unit: QuotaUnit.fromWire(json['unit'] as String?),
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
