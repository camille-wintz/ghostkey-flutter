import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/errors.dart';
import 'package:ghostkey/veil/id_card/id_card.dart';
import 'package:ghostkey/veil/id_card/render_id_card.dart';
import 'package:image/image.dart' as img;

/// Lets the card's futures and zero-length redraw timers run.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('idCardFileStem', () {
    test('folds accents and dashes the rest', () {
      expect(idCardFileStem('Élodie de Saint-Aubin'), 'elodie-de-saint-aubin');
      expect(idCardFileStem('  Ziska!  '), 'ziska');
      expect(idCardFileStem('Œdipe Straße'), 'oedipe-strasse');
    });

    test('a name with nothing to keep is "character"', () {
      expect(idCardFileStem('   '), 'character');
      expect(idCardFileStem('玛拉'), 'character');
    });
  });

  test('describeTaglineError words the codes the desk words', () {
    expect(describeTaglineError(ServerError('rate_limited', 429)), contains('give it a minute'));
    expect(describeTaglineError(ServerError('network_error', 0)), contains('offline'));
    expect(describeTaglineError(ServerError('upstream_error', 502)), 'No line came back — try another.');
    expect(describeTaglineError(StateError('x')), 'No line came back — try another.');
  });

  group('IdCard', () {
    late List<Completer<String>> asks;
    late List<List<String>> avoids;
    late List<IdCardFace> draws;

    IdCard make({Future<Uint8List?> Function()? portrait}) => IdCard(
          name: 'Mara',
          ask: (avoid) {
            avoids.add(avoid);
            final c = Completer<String>();
            asks.add(c);
            return c.future;
          },
          portrait: portrait ?? () async => null,
          draw: (face, _) async {
            draws.add(face);
            return Uint8List.fromList([draws.length]);
          },
          redrawDelay: Duration.zero,
        );

    setUp(() {
      asks = [];
      avoids = [];
      draws = [];
    });

    test('asks for nothing until started, then draws blank and again with the line', () async {
      final card = make();
      await settle();
      expect(asks, isEmpty);

      card.start();
      card.start();
      await settle();
      expect(asks, hasLength(1));
      expect(card.tagline, TaglineState.writing);
      expect(draws.single.tagline, '');
      expect(card.current, isTrue);
      expect(card.ready, isFalse, reason: 'a line is still on its way');

      asks.single.complete('Collects grudges like stamps.');
      await settle();
      expect(card.tagline, TaglineState.ready);
      expect(draws.last.tagline, 'Collects grudges like stamps.');
      expect(card.ready, isTrue);
      expect(card.fileName, 'mara-id-card.png');
    });

    test('another writes away from every line already shown', () async {
      final card = make()..start();
      asks[0].complete('one');
      await settle();
      card.another();
      expect(avoids.last, ['one']);
      asks[1].complete('two');
      await settle();
      card.another();
      expect(avoids.last, ['one', 'two']);
    });

    test("the author's own line wins over one still being written", () async {
      final card = make()..start();
      await settle();
      card.edit('My own joke');
      expect(card.current, isFalse, reason: 'the redraw has not landed');
      asks.single.complete('late line');
      await settle();
      expect(card.line, 'My own joke');
      expect(card.tagline, TaglineState.ready);
      expect(draws.last.tagline, 'My own joke');
      expect(card.ready, isTrue);
    });

    test('a failed line says why and still leaves a card to share', () async {
      final card = make()..start();
      asks.single.completeError(ServerError('rate_limited', 429));
      await settle();
      expect(card.tagline, TaglineState.failed);
      expect(card.error, contains('give it a minute'));
      expect(card.ready, isTrue);
    });

    test('a portrait that will not load draws without it', () async {
      final card = make(portrait: () async => throw ServerError('not_found', 404))..start();
      await settle();
      expect(draws, hasLength(1));
      expect(card.png, isNotNull);
    });
  });

  group('renderIdCard', () {
    testWidgets('draws a 1600x800 PNG with and without a portrait', (tester) async {
      final tall = img.Image(width: 30, height: 60);
      img.fill(tall, color: img.ColorRgb8(200, 80, 80));
      final portrait = Uint8List.fromList(img.encodePng(tall));

      for (final bytes in [portrait, null, Uint8List.fromList([1, 2, 3])]) {
        final png = await tester.runAsync(() => renderIdCard(
              const IdCardFace(
                name: 'Mara Velloso de la Cruz Fitzgerald-Ashworth',
                tagline: 'Would rather fight the sea than apologise to it, and has.',
              ),
              bytes,
            ));
        final decoded = img.decodePng(png!)!;
        expect(decoded.width, 1600);
        expect(decoded.height, 800);
      }
    });
  });
}
