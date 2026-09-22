import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/transcribe.dart';

void main() {
  test('quota_remaining is read as seconds left', () {
    final r = TranscribeResponse.fromJson({'text': 'hi', 'quota_remaining': 42});
    expect(r.quotaRead, isTrue);
    expect(r.quotaRemaining, 42);
  });

  test('a null quota_remaining is a reading: the plan does not count dictation', () {
    final r = TranscribeResponse.fromJson({'text': 'hi', 'quota_remaining': null});
    expect(r.quotaRead, isTrue);
    expect(r.quotaRemaining, isNull);
  });

  test('an absent quota_remaining is no reading at all', () {
    final r = TranscribeResponse.fromJson({'text': 'hi'});
    expect(r.quotaRead, isFalse);
  });
}
