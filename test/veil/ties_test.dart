import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/bible.dart';
import 'package:ghostkey/veil/ties.dart';

BibleEntity _entity(String name, {bool hidden = false, List<Map<String, String>>? ties}) => BibleEntity.fromJson({
      'id': 'id-$name',
      'key': name.toLowerCase(),
      'type': 'character',
      'name': name,
      'hidden': hidden,
      'ties': ?ties,
    });

DossierTie _dossierTie(String key, String relation) => DossierTie(key: key, name: key, relation: relation);

void main() {
  final mara = _entity('Mara');
  final osric = _entity('Osric');
  final ilse = _entity('Ilse');
  final gone = _entity('Gone', hidden: true);
  final roster = [mara, osric, ilse, gone];

  group('resolveTies', () {
    test("shows the dossier's ties by key until the author has a list", () {
      final ties = resolveTies(mara, [_dossierTie('osric', 'brother'), _dossierTie('gone', 'ghost')], roster);
      expect([for (final t in ties) (t.entity.id, t.relation)], [('id-Osric', 'brother')]);
    });

    test("the author's list, by id, replaces the dossier's", () {
      final authored = _entity('Mara', ties: [
        {'entity_id': 'id-Ilse', 'relation': ''},
      ]);
      final ties = resolveTies(authored, [_dossierTie('osric', 'brother')], roster);
      expect([for (final t in ties) t.entity.id], ['id-Ilse']);
    });

    test('an empty authored list is still the list', () {
      final authored = _entity('Mara', ties: []);
      expect(resolveTies(authored, [_dossierTie('osric', 'brother')], roster), isEmpty);
    });

    test('a card with no ties key falls back to the dossier', () {
      expect(mara.ties, isNull);
    });
  });

  test('tieCandidates leaves out the card, what is tied, and the hidden', () {
    final ties = resolveTies(mara, [_dossierTie('osric', 'brother')], roster);
    expect([for (final e in tieCandidates(mara, ties, roster)) e.id], ['id-Ilse']);
  });

  test('tiesToWrite carries what is on screen, in order', () {
    final ties = resolveTies(mara, [_dossierTie('osric', 'brother'), _dossierTie('ilse', 'rival')], roster);
    expect([for (final t in tiesToWrite(ties)) t.toJson()], [
      {'entity_id': 'id-Osric', 'relation': 'brother'},
      {'entity_id': 'id-Ilse', 'relation': 'rival'},
    ]);
  });
}
