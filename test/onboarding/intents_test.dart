import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/rooms/rooms.dart';
import 'package:ghostkey/screens/onboarding/intents.dart';
import 'package:ghostkey/server/dto/profile.dart';

// Which rooms this phone offers, and which it points at afterwards. The desk
// answers the same five intents with seven rooms; these assertions are the
// record of where the two deliberately differ.

void main() {
  group('intentOptions', () {
    test('offers three, and never one that leads nowhere', () {
      final options = intentOptions();
      expect(options.length, 3);
      for (final option in options) {
        expect(rooms.map((r) => r.key), contains(option.room));
      }
    });

    test('never offers pitch — Glamour has no room here', () {
      expect(intentOptions().map((o) => o.intent), isNot(contains(Intent.pitch)));
    });

    test('plot ends in the chat, because there is no Mara on a phone', () {
      final plot = intentOptions().firstWhere((o) => o.intent == Intent.plot);
      expect(plot.opensChat, isTrue);
      expect(plot.room, RoomKey.phantom);
    });
  });

  group('markFor', () {
    test('marks the room an intent opens', () {
      expect(markFor(Intent.draft)?.room, RoomKey.apparition);
      expect(markFor(Intent.worldbuild)?.room, RoomKey.veil);
    });

    test('marks nothing for an intent that ended in the chat', () {
      // The author is already in the conversation; pointing at the room they
      // came out of would be pointing backwards.
      expect(markFor(Intent.plot), isNull);
      expect(markFor(Intent.guided), isNull);
    });

    test('marks nothing for an intent this client does not answer', () {
      expect(markFor(Intent.pitch), isNull);
    });

    test('marks nothing when the flow was skipped', () {
      expect(markFor(null), isNull);
    });
  });
}
