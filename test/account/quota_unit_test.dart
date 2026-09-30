import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/billing.dart';

void main() {
  test('seconds read as minutes, floored; runs stay bare', () {
    expect(formatQuantity(3600, QuotaUnit.seconds), '1 h');
    expect(formatQuantity(1830, QuotaUnit.seconds), '30 min');
    expect(formatQuantity(4859, QuotaUnit.seconds), '1 h 20 min');
    expect(formatQuantity(59, QuotaUnit.seconds), '0 min');
    expect(formatQuantity(3, QuotaUnit.runs), '3');
  });

  test('credits say their unit, once in a count', () {
    expect(formatQuantity(140, QuotaUnit.credits), '140 credits');
    expect(formatQuantity(1, QuotaUnit.credits), '1 credit');
    expect(formatUsage(50, 190, QuotaUnit.credits, false), '50 / 190 credits');
    expect(formatUsage(50, 200, QuotaUnit.credits, true), '25% used');
    expect(QuotaUnit.fromWire('credits'), QuotaUnit.credits);
  });

  test('the wire unit defaults to runs', () {
    final f = FeatureQuota.fromJson({'feature': 'edit_pass', 'label': 'x', 'used': 1});
    expect(f.unit, QuotaUnit.runs);
    final d = FeatureQuota.fromJson({'feature': 'dictation', 'label': 'Dictation', 'unit': 'seconds', 'used': 60});
    expect(d.unit, QuotaUnit.seconds);
  });
}
