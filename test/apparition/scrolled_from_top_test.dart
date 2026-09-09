import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/screens/apparition/scrolled_from_top.dart';

void main() {
  test('flips at 24 going down and at 8 coming back, and fires only on the flip', () {
    final s = ScrolledFromTop();
    var fired = 0;
    s.addListener(() => fired++);
    s.onOffset(20);
    expect(s.value, isFalse);
    s.onOffset(25);
    expect(s.value, isTrue);
    s.onOffset(12);
    expect(s.value, isTrue);
    s.onOffset(7);
    expect(s.value, isFalse);
    expect(fired, 2);
    s.dispose();
  });
}
