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
}) =>
    FeatureQuota(
      feature: feature,
      label: label,
      cadence: cadence,
      periodEnd: '2026-09-14T00:00:00Z',
      unlimited: unlimited,
      allowance: allowance,
      used: allowance == null || remaining == null ? 0 : allowance - remaining,
      remaining: remaining,
    );

QuotaSnapshot snapshot(List<FeatureQuota> features) =>
    QuotaSnapshot(plan: Plan.basic, periodEnd: '2026-09-14T00:00:00Z', features: features);

void main() {
  group('chatQuotaFor', () {
    test('an absent snapshot gates nothing', () {
      final gate = chatQuotaFor(null, 'gpt-5-6-terra');
      expect(gate.exhausted, isFalse);
      expect(gate.feature, 'phantom_chat');
    });
    test('the weekly counter binds an included model', () {
      final spent = snapshot([quota('phantom_chat', remaining: 0)]);
      expect(chatQuotaFor(spent, 'gpt-5-6-terra').exhausted, isTrue);
      expect(chatQuotaFor(spent, 'gpt-5-6-terra').feature, 'phantom_chat');
      final left = snapshot([quota('phantom_chat', remaining: 3)]);
      expect(chatQuotaFor(left, 'gpt-5-6-terra').exhausted, isFalse);
    });
    test("Fable's own counter is named when it is the spent one", () {
      final fableSpent = snapshot([
        quota('phantom_chat', remaining: 10),
        quota('fable_chat', remaining: 0, allowance: 5, label: 'Fable messages'),
      ]);
      final gate = chatQuotaFor(fableSpent, 'fable-5');
      expect(gate.exhausted, isTrue);
      expect(gate.feature, 'fable_chat');
    });
    test('the weekly counter still binds Fable when only it is spent', () {
      final weeklySpent = snapshot([
        quota('phantom_chat', remaining: 0),
        quota('fable_chat', remaining: 4, allowance: 5),
      ]);
      final gate = chatQuotaFor(weeklySpent, 'fable-5');
      expect(gate.exhausted, isTrue);
      expect(gate.feature, 'phantom_chat');
    });
    test("a model's counter missing from the snapshot does not gate", () {
      final noFable = snapshot([quota('phantom_chat', remaining: 2)]);
      expect(chatQuotaFor(noFable, 'fable-5').exhausted, isFalse);
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
    test('draws nothing when unlimited or unknown', () {
      expect(quotaLine(null), isNull);
      expect(quotaLine(quota('phantom_chat', remaining: null, allowance: null, unlimited: true)), isNull);
      expect(quotaLine(quota('phantom_chat', remaining: null, allowance: 15)), isNull);
    });
  });
}
