import 'billing.dart';
import 'json.dart';

// The gift plan's wire shapes — `GiftRead`, `GiftGiving`, `GiftHolding` and
// `GiftOffer` in openapi.yaml. Buy one, give one: every paid subscription
// comes with one free Basic to give to one other person. The server mints
// the code, keeps who took it and decides every refusal.

/// What a gift code gives the account that takes it.
class GiftOffer {
  const GiftOffer({required this.plan});
  final Plan plan;

  static GiftOffer fromJson(Json json) => GiftOffer(plan: Plan.fromWire(json['plan'] as String?));
}

/// Who took the gift, and when. `by` is the receiver's address masked to its
/// first letter and domain.
class GiftClaim {
  const GiftClaim({required this.by, required this.at});
  final String by;
  final String at;

  static GiftClaim fromJson(Json json) => GiftClaim(by: asString(json['by']), at: asString(json['at']));
}

/// The gift an account can give — one per paying account, ever.
class GiftGiving {
  const GiftGiving({
    required this.plan,
    required this.code,
    required this.link,
    required this.active,
    required this.claimed,
  });

  final Plan plan;
  final String code;
  final String link;

  /// Whether the code can be taken right now — the giver has a live
  /// subscription. False between a lapse and a return.
  final bool active;
  final GiftClaim? claimed;

  static GiftGiving fromJson(Json json) => GiftGiving(
        plan: Plan.fromWire(json['plan'] as String?),
        code: asString(json['code']),
        link: asString(json['link']),
        active: asBool(json['active']),
        claimed: json['claimed'] is Map ? GiftClaim.fromJson(asJson(json['claimed'])) : null,
      );
}

/// The gift an account took from a friend.
class GiftHolding {
  const GiftHolding({required this.plan, required this.expiresAt, required this.active});

  final Plan plan;
  final String? expiresAt;

  /// False once the giver stopped paying: the account reads as Free again,
  /// and it resumes on its own if they return.
  final bool active;

  static GiftHolding fromJson(Json json) => GiftHolding(
        plan: Plan.fromWire(json['plan'] as String?),
        expiresAt: json['expires_at'] as String?,
        active: asBool(json['active']),
      );
}

/// Both sides of an account's gift.
class GiftRead {
  const GiftRead({required this.giving, required this.holding});

  /// Null until the account has paid for a plan.
  final GiftGiving? giving;

  /// Null unless a gift was ever taken on this account.
  final GiftHolding? holding;

  static GiftRead fromJson(Json json) => GiftRead(
        giving: json['giving'] is Map ? GiftGiving.fromJson(asJson(json['giving'])) : null,
        holding: json['holding'] is Map ? GiftHolding.fromJson(asJson(json['holding'])) : null,
      );
}
