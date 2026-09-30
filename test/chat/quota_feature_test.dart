import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/chat/quota_feature.dart';
import 'package:ghostkey/server/dto/billing.dart';

FeatureQuota quota(
  String feature, {
  required int? remaining,
  int? allowance = 15,
  bool unlimited = false,
  QuotaCadence cadence = QuotaCadence.weekly,
  String label = 'Chat messages',
  int extras = 0,
}) =>
    FeatureQuota(
      feature: feature,
      label: label,
      cadence: cadence,
      periodEnd: '2026-09-14T00:00:00Z',
      unlimited: unlimited,
      allowance: allowance,
      used: allowance == null || remaining == null ? 0 : allowance - remaining - extras,
      extras: extras,
      remaining: remaining,
    );

QuotaSnapshot snapshot(List<FeatureQuota> features) =>
    QuotaSnapshot(plan: Plan.basic, periodEnd: '2026-09-14T00:00:00Z', features: features);

// A snapshot as the server sends it since 2026-09-30: the chat priced out of
// the weekly credits, which carry the numbers.
FeatureQuota credits({required int remaining, int allowance = 190}) => FeatureQuota(
      feature: 'credits',
      label: 'Credits',
      cadence: QuotaCadence.weekly,
      periodEnd: '2026-10-05T00:00:00Z',
      unlimited: false,
      allowance: allowance,
      used: allowance - remaining,
      extras: 0,
      remaining: remaining,
      unit: QuotaUnit.credits,
    );

FeatureQuota pooled(String feature, {required int remaining, double price = 1}) => FeatureQuota(
      feature: feature,
      label: 'Chat messages',
      cadence: QuotaCadence.weekly,
      periodEnd: '2026-10-05T00:00:00Z',
      unlimited: false,
      allowance: null,
      used: 0,
      extras: 0,
      remaining: remaining,
      pool: 'credits',
      price: price,
    );

void main() {
  group('chatQuotaFor', () {
    test('no snapshot gates nothing, on the chat counter', () {
      final gate = chatQuotaFor(null);
      expect(gate.exhausted, isFalse);
      expect(gate.feature, 'phantom_chat');
    });
    test('a chat counted on its own gates on it (an older server)', () {
      final spent = snapshot([quota('phantom_chat', remaining: 0)]);
      expect(chatQuotaFor(spent).exhausted, isTrue);
      expect(chatQuotaFor(spent).feature, 'phantom_chat');
      final left = snapshot([quota('phantom_chat', remaining: 3)]);
      expect(chatQuotaFor(left).exhausted, isFalse);
    });
    test('a pooled chat gates on the credits and names them', () {
      final spent = snapshot([credits(remaining: 0), pooled('phantom_chat', remaining: 0)]);
      final gate = chatQuotaFor(spent);
      expect(gate.exhausted, isTrue);
      expect(gate.feature, 'credits');
      expect(chatQuotaFor(snapshot([credits(remaining: 1), pooled('phantom_chat', remaining: 1)])).exhausted, isFalse);
    });
    test('an unlimited chat gates nothing', () {
      final open = snapshot([
        quota('phantom_chat', remaining: null, allowance: null, unlimited: true),
        credits(remaining: 0),
      ]);
      expect(chatQuotaFor(open).exhausted, isFalse);
    });
  });

  group('QuotaSnapshot.lineFor', () {
    test("a pooled feature resolves to its pool's line", () {
      final s = snapshot([credits(remaining: 140), pooled('edit_pass', remaining: 5, price: 25)]);
      expect(s.lineFor('edit_pass')?.feature, 'credits');
      expect(s.feature('edit_pass')?.remaining, 5);
    });
    test('an unpooled feature, or a pool the snapshot lacks, is its own line', () {
      final s = snapshot([quota('reverse_outline', remaining: 2), pooled('edit_pass', remaining: 5)]);
      expect(s.lineFor('reverse_outline')?.feature, 'reverse_outline');
      expect(s.lineFor('edit_pass')?.feature, 'edit_pass');
      expect(s.lineFor('missing'), isNull);
    });
    test('reads pool and price off the wire, tolerating their absence', () {
      final f = FeatureQuota.fromJson({
        'feature': 'dictation',
        'label': 'Dictation',
        'unit': 'seconds',
        'used': 0,
        'pool': 'credits',
        'price': 0.016666666666666666,
      });
      expect(f.pool, 'credits');
      expect(f.price, closeTo(1 / 60, 1e-9));
      final whole = FeatureQuota.fromJson({'feature': 'edit_pass', 'label': 'x', 'used': 0, 'pool': 'credits', 'price': 25});
      expect(whole.price, 25.0);
      final old = FeatureQuota.fromJson({'feature': 'edit_pass', 'label': 'x', 'used': 0});
      expect(old.pool, isNull);
      expect(old.price, isNull);
    });
  });

  group('quotaLine', () {
    test('words the weekly line', () {
      expect(quotaLine(quota('phantom_chat', remaining: 12)), '12 of 15 chat messages left this week');
    });
    test('says "this period" for a billing cadence', () {
      expect(
        quotaLine(quota('phantom_chat', remaining: 1, cadence: QuotaCadence.billing)),
        '1 of 15 chat messages left this period',
      );
    });
    test("the credits' line counts credits", () {
      expect(quotaLine(credits(remaining: 140)), '140 of 190 credits left this week');
    });
    test('draws nothing when unlimited or unknown', () {
      expect(quotaLine(null), isNull);
      expect(quotaLine(quota('phantom_chat', remaining: null, allowance: null, unlimited: true)), isNull);
      expect(quotaLine(quota('phantom_chat', remaining: null, allowance: 15)), isNull);
      // A pooled feature's own entry has no allowance: read its pool's line.
      expect(quotaLine(pooled('edit_pass', remaining: 5)), isNull);
    });
  });
}
