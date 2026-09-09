// ignore_for_file: prefer_single_quotes
// GENERATED from ../ghostkey-mobile/src/lib/typography.ts by running the
// TypeScript original over a fixed case table (see docs in the port plan).
// The four copies of this transform are one text: a case that fails here
// means the Dart copy has drifted from the others.

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/core/typography.dart';

TypographyMode mode(String m) => TypographyMode.values.byName(m);

void main() {
  group('applyTypography matches the TypeScript original', () {
    test('curly #0', () => expect(applyTypography("\"Hello,\" she said.", "", mode('curly')), "\u201cHello,\u201d she said."));
    test('curly #1', () => expect(applyTypography("It's a dog's life", "", mode('curly')), "It\u2019s a dog\u2019s life"));
    test('curly #2', () => expect(applyTypography("'Quoted' word", "", mode('curly')), "\u2018Quoted\u2019 word"));
    test('curly #3', () => expect(applyTypography("Wait -- what...", "", mode('curly')), "Wait \u2014 what\u2026"));
    test('curly #4', () => expect(applyTypography("Bonjour ! \u00c7a va ? Oui : non ; bien.", "", mode('curly')), "Bonjour ! \u00c7a va ? Oui : non ; bien."));
    test('curly #5', () => expect(applyTypography("\"Bonjour\" dit-il", "", mode('curly')), "\u201cBonjour\u201d dit-il"));
    test('curly #6', () => expect(applyTypography("\u00ab Salut \u00bb dit-elle", "", mode('curly')), "\u00ab Salut \u00bb dit-elle"));
    test('curly #7', () => expect(applyTypography("She said \"hi", "He said \"", mode('curly')), "She said \u201dhi"));
    test('curly #8', () => expect(applyTypography("rock 'n' roll", "", mode('curly')), "rock \u2018n\u2019 roll"));
    test('curly #9', () => expect(applyTypography("end.\"", "She said \"the ", mode('curly')), "end.\u201d"));
    test('curly #10', () => expect(applyTypography("1990's", "", mode('curly')), "1990\u2019s"));
    test('curly #11', () => expect(applyTypography("\"Nested 'inner' quote\"", "", mode('curly')), "\u201cNested \u2018inner\u2019 quote\u201d"));
    test('guillemets #12', () => expect(applyTypography("\"Hello,\" she said.", "", mode('guillemets')), "\u00ab\u202fHello,\u202f\u00bb she said."));
    test('guillemets #13', () => expect(applyTypography("It's a dog's life", "", mode('guillemets')), "It\u2019s a dog\u2019s life"));
    test('guillemets #14', () => expect(applyTypography("'Quoted' word", "", mode('guillemets')), "\u2018Quoted\u2019 word"));
    test('guillemets #15', () => expect(applyTypography("Wait -- what...", "", mode('guillemets')), "Wait \u2014 what\u2026"));
    test('guillemets #16', () => expect(applyTypography("Bonjour ! \u00c7a va ? Oui : non ; bien.", "", mode('guillemets')), "Bonjour\u202f! \u00c7a va\u202f? Oui\u00a0: non\u202f; bien."));
    test('guillemets #17', () => expect(applyTypography("\"Bonjour\" dit-il", "", mode('guillemets')), "\u00ab\u202fBonjour\u202f\u00bb dit-il"));
    test('guillemets #18', () => expect(applyTypography("\u00ab Salut \u00bb dit-elle", "", mode('guillemets')), "\u00ab\u202fSalut\u202f\u00bb dit-elle"));
    test('guillemets #19', () => expect(applyTypography("She said \"hi", "He said \"", mode('guillemets')), "She said\u202f\u00bbhi"));
    test('guillemets #20', () => expect(applyTypography("rock 'n' roll", "", mode('guillemets')), "rock \u2018n\u2019 roll"));
    test('guillemets #21', () => expect(applyTypography("end.\"", "She said \"the ", mode('guillemets')), "end.\u202f\u00bb"));
    test('guillemets #22', () => expect(applyTypography("1990's", "", mode('guillemets')), "1990\u2019s"));
    test('guillemets #23', () => expect(applyTypography("\"Nested 'inner' quote\"", "", mode('guillemets')), "\u00ab\u202fNested \u2018inner\u2019 quote\u202f\u00bb"));
    test('german #24', () => expect(applyTypography("\"Hello,\" she said.", "", mode('german')), "\u201eHello,\u201c she said."));
    test('german #25', () => expect(applyTypography("It's a dog's life", "", mode('german')), "It\u2019s a dog\u2019s life"));
    test('german #26', () => expect(applyTypography("'Quoted' word", "", mode('german')), "\u201aQuoted\u2018 word"));
    test('german #27', () => expect(applyTypography("Wait -- what...", "", mode('german')), "Wait \u2014 what\u2026"));
    test('german #28', () => expect(applyTypography("Bonjour ! \u00c7a va ? Oui : non ; bien.", "", mode('german')), "Bonjour ! \u00c7a va ? Oui : non ; bien."));
    test('german #29', () => expect(applyTypography("\"Bonjour\" dit-il", "", mode('german')), "\u201eBonjour\u201c dit-il"));
    test('german #30', () => expect(applyTypography("\u00ab Salut \u00bb dit-elle", "", mode('german')), "\u00ab Salut \u00bb dit-elle"));
    test('german #31', () => expect(applyTypography("She said \"hi", "He said \"", mode('german')), "She said \u201chi"));
    test('german #32', () => expect(applyTypography("rock 'n' roll", "", mode('german')), "rock \u201an\u2018 roll"));
    test('german #33', () => expect(applyTypography("end.\"", "She said \"the ", mode('german')), "end.\u201c"));
    test('german #34', () => expect(applyTypography("1990's", "", mode('german')), "1990\u2019s"));
    test('german #35', () => expect(applyTypography("\"Nested 'inner' quote\"", "", mode('german')), "\u201eNested \u201ainner\u2018 quote\u201c"));
    test('none #36', () => expect(applyTypography("\"Hello,\" she said.", "", mode('none')), "\"Hello,\" she said."));
    test('none #37', () => expect(applyTypography("It's a dog's life", "", mode('none')), "It's a dog's life"));
    test('none #38', () => expect(applyTypography("'Quoted' word", "", mode('none')), "'Quoted' word"));
    test('none #39', () => expect(applyTypography("Wait -- what...", "", mode('none')), "Wait -- what..."));
    test('none #40', () => expect(applyTypography("Bonjour ! \u00c7a va ? Oui : non ; bien.", "", mode('none')), "Bonjour ! \u00c7a va ? Oui : non ; bien."));
    test('none #41', () => expect(applyTypography("\"Bonjour\" dit-il", "", mode('none')), "\"Bonjour\" dit-il"));
    test('none #42', () => expect(applyTypography("\u00ab Salut \u00bb dit-elle", "", mode('none')), "\u00ab Salut \u00bb dit-elle"));
    test('none #43', () => expect(applyTypography("She said \"hi", "He said \"", mode('none')), "She said \"hi"));
    test('none #44', () => expect(applyTypography("rock 'n' roll", "", mode('none')), "rock 'n' roll"));
    test('none #45', () => expect(applyTypography("end.\"", "She said \"the ", mode('none')), "end.\""));
    test('none #46', () => expect(applyTypography("1990's", "", mode('none')), "1990's"));
    test('none #47', () => expect(applyTypography("\"Nested 'inner' quote\"", "", mode('none')), "\"Nested 'inner' quote\""));
  });

  group('applySmartEdit matches the TypeScript original', () {
    test('curly #0', () {
      final e = applySmartEdit("She said ", "She said \"", mode('curly'))!;
      expect(e.text, "She said \u201c");
      expect(e.cursor, 10);
    });
    test('curly #1', () {
      final e = applySmartEdit("She said \"hi", "She said \"hi\"", mode('curly'))!;
      expect(e.text, "She said \"hi\u201d");
      expect(e.cursor, 13);
    });
    test('curly #2', () {
      final e = applySmartEdit("Wait -", "Wait --", mode('curly'))!;
      expect(e.text, "Wait \u2014");
      expect(e.cursor, 6);
    });
    test('curly #3', () {
      final e = applySmartEdit("Wait..", "Wait...", mode('curly'))!;
      expect(e.text, "Wait\u2026");
      expect(e.cursor, 5);
    });
    test('curly #4', () => expect(applySmartEdit("Bonjour", "Bonjour !", mode('curly')), isNull));
    test('curly #5', () => expect(applySmartEdit("Bonjour ", "Bonjour !", mode('curly')), isNull));
    test('curly #6', () => expect(applySmartEdit("\u00ab Salut", "\u00ab Salut \u00bb", mode('curly')), isNull));
    test('curly #7', () => expect(applySmartEdit("\u00ab Salut ", "\u00ab Salut \u00bb", mode('curly')), isNull));
    test('curly #8', () => expect(applySmartEdit("\u00ab\u202f", "\u00ab\u202f ", mode('curly')), isNull));
    test('curly #9', () {
      final e = applySmartEdit("It", "It'", mode('curly'))!;
      expect(e.text, "It\u2019");
      expect(e.cursor, 3);
    });
    test('curly #10', () => expect(applySmartEdit("It's", "It's ", mode('curly')), isNull));
    test('curly #11', () => expect(applySmartEdit("abc", "abd", mode('curly')), isNull));
    test('guillemets #12', () {
      final e = applySmartEdit("She said ", "She said \"", mode('guillemets'))!;
      expect(e.text, "She said \u00ab\u202f");
      expect(e.cursor, 11);
    });
    test('guillemets #13', () {
      final e = applySmartEdit("She said \"hi", "She said \"hi\"", mode('guillemets'))!;
      expect(e.text, "She said \"hi\u202f\u00bb");
      expect(e.cursor, 14);
    });
    test('guillemets #14', () {
      final e = applySmartEdit("Wait -", "Wait --", mode('guillemets'))!;
      expect(e.text, "Wait \u2014");
      expect(e.cursor, 6);
    });
    test('guillemets #15', () {
      final e = applySmartEdit("Wait..", "Wait...", mode('guillemets'))!;
      expect(e.text, "Wait\u2026");
      expect(e.cursor, 5);
    });
    test('guillemets #16', () {
      final e = applySmartEdit("Bonjour", "Bonjour !", mode('guillemets'))!;
      expect(e.text, "Bonjour\u202f!");
      expect(e.cursor, 9);
    });
    test('guillemets #17', () {
      final e = applySmartEdit("Bonjour ", "Bonjour !", mode('guillemets'))!;
      expect(e.text, "Bonjour\u202f!");
      expect(e.cursor, 9);
    });
    test('guillemets #18', () {
      final e = applySmartEdit("\u00ab Salut", "\u00ab Salut \u00bb", mode('guillemets'))!;
      expect(e.text, "\u00ab Salut\u202f\u00bb");
      expect(e.cursor, 9);
    });
    test('guillemets #19', () {
      final e = applySmartEdit("\u00ab Salut ", "\u00ab Salut \u00bb", mode('guillemets'))!;
      expect(e.text, "\u00ab Salut\u202f\u00bb");
      expect(e.cursor, 9);
    });
    test('guillemets #20', () {
      final e = applySmartEdit("\u00ab\u202f", "\u00ab\u202f ", mode('guillemets'))!;
      expect(e.text, "\u00ab\u202f");
      expect(e.cursor, 2);
    });
    test('guillemets #21', () {
      final e = applySmartEdit("It", "It'", mode('guillemets'))!;
      expect(e.text, "It\u2019");
      expect(e.cursor, 3);
    });
    test('guillemets #22', () => expect(applySmartEdit("It's", "It's ", mode('guillemets')), isNull));
    test('guillemets #23', () => expect(applySmartEdit("abc", "abd", mode('guillemets')), isNull));
    test('german #24', () {
      final e = applySmartEdit("She said ", "She said \"", mode('german'))!;
      expect(e.text, "She said \u201e");
      expect(e.cursor, 10);
    });
    test('german #25', () {
      final e = applySmartEdit("She said \"hi", "She said \"hi\"", mode('german'))!;
      expect(e.text, "She said \"hi\u201c");
      expect(e.cursor, 13);
    });
    test('german #26', () {
      final e = applySmartEdit("Wait -", "Wait --", mode('german'))!;
      expect(e.text, "Wait \u2014");
      expect(e.cursor, 6);
    });
    test('german #27', () {
      final e = applySmartEdit("Wait..", "Wait...", mode('german'))!;
      expect(e.text, "Wait\u2026");
      expect(e.cursor, 5);
    });
    test('german #28', () => expect(applySmartEdit("Bonjour", "Bonjour !", mode('german')), isNull));
    test('german #29', () => expect(applySmartEdit("Bonjour ", "Bonjour !", mode('german')), isNull));
    test('german #30', () => expect(applySmartEdit("\u00ab Salut", "\u00ab Salut \u00bb", mode('german')), isNull));
    test('german #31', () => expect(applySmartEdit("\u00ab Salut ", "\u00ab Salut \u00bb", mode('german')), isNull));
    test('german #32', () => expect(applySmartEdit("\u00ab\u202f", "\u00ab\u202f ", mode('german')), isNull));
    test('german #33', () {
      final e = applySmartEdit("It", "It'", mode('german'))!;
      expect(e.text, "It\u2019");
      expect(e.cursor, 3);
    });
    test('german #34', () => expect(applySmartEdit("It's", "It's ", mode('german')), isNull));
    test('german #35', () => expect(applySmartEdit("abc", "abd", mode('german')), isNull));
    test('none #36', () => expect(applySmartEdit("She said ", "She said \"", mode('none')), isNull));
    test('none #37', () => expect(applySmartEdit("She said \"hi", "She said \"hi\"", mode('none')), isNull));
    test('none #38', () => expect(applySmartEdit("Wait -", "Wait --", mode('none')), isNull));
    test('none #39', () => expect(applySmartEdit("Wait..", "Wait...", mode('none')), isNull));
    test('none #40', () => expect(applySmartEdit("Bonjour", "Bonjour !", mode('none')), isNull));
    test('none #41', () => expect(applySmartEdit("Bonjour ", "Bonjour !", mode('none')), isNull));
    test('none #42', () => expect(applySmartEdit("\u00ab Salut", "\u00ab Salut \u00bb", mode('none')), isNull));
    test('none #43', () => expect(applySmartEdit("\u00ab Salut ", "\u00ab Salut \u00bb", mode('none')), isNull));
    test('none #44', () => expect(applySmartEdit("\u00ab\u202f", "\u00ab\u202f ", mode('none')), isNull));
    test('none #45', () => expect(applySmartEdit("It", "It'", mode('none')), isNull));
    test('none #46', () => expect(applySmartEdit("It's", "It's ", mode('none')), isNull));
    test('none #47', () => expect(applySmartEdit("abc", "abd", mode('none')), isNull));
  });
}
