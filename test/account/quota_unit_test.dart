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

  test('the wire unit defaults to runs', () {
    final f = FeatureQuota.fromJson({'feature': 'edit_pass', 'label': 'x', 'used': 1});
    expect(f.unit, QuotaUnit.runs);
    final d = FeatureQuota.fromJson({'feature': 'dictation', 'label': 'Dictation', 'unit': 'seconds', 'used': 60});
    expect(d.unit, QuotaUnit.seconds);
  });
}
