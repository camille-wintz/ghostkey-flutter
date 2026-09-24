import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/bible.dart';
import 'package:ghostkey/veil/roster.dart';

BibleEntity _entity(String name, {List<String> aliases = const [], Map<String, String>? gmc}) =>
    BibleEntity.fromJson({
      'id': 'id-$name',
      'key': name.toLowerCase(),
      'type': 'character',
      'name': name,
      'aliases': aliases,
      'gmc': ?gmc,
    });

void main() {
  group('entityAnsweringTo', () {
    final entities = [
      _entity('Mara Venn', aliases: ['Mara']),
      _entity('Élodie'),
    ];

    test('matches a name or an alias, whatever the case and spacing', () {
      expect(entityAnsweringTo(entities, 'mara  venn')?.id, 'id-Mara Venn');
      expect(entityAnsweringTo(entities, ' MARA ')?.id, 'id-Mara Venn');
    });

    test('folds accents the way the search does', () {
      expect(entityAnsweringTo(entities, 'elodie')?.id, 'id-Élodie');
    });

    test('answers null for a new name or an empty one', () {
      expect(entityAnsweringTo(entities, 'Osric'), isNull);
      expect(entityAnsweringTo(entities, '   '), isNull);
    });
  });

  group('the single-entity wire', () {
    test("a card carries the author's GMC, only the filled cells", () {
      final card = _entity('Mara', gmc: {'External goal': 'Keep the light lit'});
      expect(card.gmc, {'External goal': 'Keep the light lit'});
      expect(_entity('Osric').gmc, isEmpty);
    });

    test('an edit answers with the card id, the bible, and the refused spellings', () {
      final written = BibleEntityWriteResponse.fromJson({
        'id': 'id-Mara',
        'rejected': ['Osric'],
        'spellings': <String>[],
        'bible': {
          'series_id': 's1',
          'entities': [
            {'id': 'id-Mara', 'key': 'mara', 'type': 'character', 'name': 'Mara'},
          ],
        },
      });
      expect(written.id, 'id-Mara');
      expect(written.rejected, ['Osric']);
      expect(written.bible.entities.single.name, 'Mara');
    });

    test('an add answers with no refused spellings', () {
      final written = BibleEntityWriteResponse.fromJson({'id': 'x', 'bible': null, 'spellings': <String>[]});
      expect(written.rejected, isEmpty);
    });
  });
}
