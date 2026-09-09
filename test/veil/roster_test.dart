import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/bible.dart';
import 'package:ghostkey/veil/roster.dart';

const _book1 = 'p1';
const _book2 = 'p2';

BibleEntity _entity(
  String name, {
  BibleEntityType type = BibleEntityType.character,
  int mentions = 0,
  int mentionsInBook2 = 0,
  List<String> aliases = const [],
  String? extractedName,
  bool hidden = false,
  BibleEntityOrigin origin = BibleEntityOrigin.extracted,
  bool twoBooks = true,
}) =>
    BibleEntity.fromJson({
      'id': 'id-$name',
      'key': name.toLowerCase(),
      'type': type.name,
      'name': name,
      'extracted_name': extractedName ?? name,
      'aliases': aliases,
      'first_appearance': mentions > 0 ? 'Chapter 1.md' : '',
      'mention_count': mentions,
      'hidden': hidden,
      'chapters': [for (var i = 0; i < mentions; i++) 'Chapter ${i + 1}.md'],
      'noted_chapters': <String>[],
      'books': [
        {
          'project_id': _book1,
          'project_name': 'Book One',
          'chapters': <String>[],
          'noted_chapters': <String>[],
          'mention_count': mentions,
          'first_appearance': '',
        },
        if (twoBooks)
          {
            'project_id': _book2,
            'project_name': 'Book Two',
            'chapters': <String>[],
            'noted_chapters': <String>[],
            'mention_count': mentionsInBook2,
            'first_appearance': mentionsInBook2 > 0 ? 'Chapter 3.md' : '',
          },
      ],
      'planned_chapters': <String>[],
      'notes': '',
      'physical_description': '',
      'origin': origin.name,
    });

void main() {
  group('BibleEntity.fromJson', () {
    test('reads the contract fields, folding empty strings to null', () {
      final e = _entity('Ada', mentions: 2, mentionsInBook2: 1);
      expect(e.origin, BibleEntityOrigin.extracted);
      expect(e.isUser, isFalse);
      expect(e.extractedName, 'Ada');
      expect(e.firstAppearance, 'Chapter 1.md');
      expect(e.imageAssetId, isNull);
      expect(e.books, hasLength(2));
      expect(e.books[1].title, 'Book Two');
      expect(e.books[0].firstAppearance, isNull);
      expect(e.books[1].firstAppearance, 'Chapter 3.md');
      expect(_entity('Nobody').firstAppearance, isNull);
    });

    test('mentionsIn reads the flat count for null and the book ref otherwise', () {
      final e = _entity('Ada', mentions: 5, mentionsInBook2: 2);
      expect(e.mentionsIn(null), 5);
      expect(e.mentionsIn(_book2), 2);
      expect(e.mentionsIn('unknown'), 0);
    });
  });

  group('buildRoster', () {
    final entities = [
      _entity('Zed', mentions: 3),
      _entity('Ada', mentions: 9),
      _entity('Bea', mentions: 3),
      _entity('Keep', type: BibleEntityType.place, mentions: 4),
      _entity('Ash', type: BibleEntityType.term, mentions: 1),
      _entity('Ghost', hidden: true, mentions: 7),
      _entity('Stella', origin: BibleEntityOrigin.user),
      _entity('Élodie', mentions: 0, mentionsInBook2: 6, aliases: ['the widow']),
    ];

    test('groups character → place → term, each sorted by presence then name', () {
      final view = buildRoster(entities);
      expect(view.groups.map((g) => g.type), [BibleEntityType.character, BibleEntityType.place, BibleEntityType.term]);
      expect(view.groups[0].entities.map((e) => e.name), ['Ada', 'Bea', 'Zed', 'Élodie', 'Stella']);
      expect(view.groups[1].entities.single.name, 'Keep');
      expect(view.groups[2].entities.single.name, 'Ash');
    });

    test('separates the hidden pile and counts the visible total', () {
      final view = buildRoster(entities);
      expect(view.hidden.map((e) => e.name), ['Ghost']);
      expect(view.total, 7);
      expect(view.shown, 7);
      expect(view.peak, 9);
    });

    test('the book tab drops entities this book never mentions, keeps author-added ones, re-scales the peak', () {
      final view = buildRoster(entities, book: _book2);
      final names = view.groups.expand((g) => g.entities).map((e) => e.name).toList();
      expect(names, ['Élodie', 'Stella']);
      expect(view.peak, 6);
      expect(view.total, 2);
    });

    test('the type tab narrows without touching the total', () {
      final view = buildRoster(entities, type: BibleEntityType.place);
      expect(view.groups.single.entities.single.name, 'Keep');
      expect(view.shown, 1);
      expect(view.total, 7);
    });

    test('search is accent- and case-blind over name, extracted name and aliases', () {
      expect(buildRoster(entities, query: 'elodie').shown, 1);
      expect(buildRoster(entities, query: 'ÉLO').shown, 1);
      expect(buildRoster(entities, query: 'widow').shown, 1);
      expect(buildRoster(entities, query: 'nobody').groups, isEmpty);
      final renamed = _entity('Ada Kell', extractedName: 'ada kellas', mentions: 1);
      expect(matchesEntity(renamed, 'kellas'), isTrue);
    });

    test('a query and a type tab compose', () {
      final view = buildRoster(entities, query: 'a', type: BibleEntityType.character);
      expect(view.groups.single.entities.map((e) => e.name), ['Ada', 'Bea', 'Stella']);
    });

    test('peak is never below one', () {
      expect(buildRoster([_entity('Stella', origin: BibleEntityOrigin.user)]).peak, 1);
      expect(buildRoster(const []).peak, 1);
    });
  });

  group('bookTabs', () {
    test('is empty for a standalone and lists every book of a series in order', () {
      expect(bookTabs([_entity('Ada', twoBooks: false)]), isEmpty);
      final tabs = bookTabs([_entity('Ada'), _entity('Bea')]);
      expect(tabs.map((t) => t.id), [_book1, _book2]);
      expect(tabs.map((t) => t.label), ['Book One', 'Book Two']);
    });
  });

  group('presence', () {
    test('appearsElsewhere means zero here and some in a sibling', () {
      expect(appearsElsewhere(_entity('Élodie', mentionsInBook2: 6), _book1), isTrue);
      expect(appearsElsewhere(_entity('Ada', mentions: 2), _book1), isFalse);
      expect(appearsElsewhere(_entity('Stella', origin: BibleEntityOrigin.user), _book1), isFalse);
    });

    test('presenceFraction floors a walk-on at a sliver and zero at nothing', () {
      expect(presenceFraction(0, 10), 0);
      expect(presenceFraction(1, 100), 0.06);
      expect(presenceFraction(5, 10), 0.5);
      expect(presenceFraction(10, 10), 1);
      expect(presenceFraction(3, 0), 1);
    });
  });

  group('display helpers', () {
    test('titleCase capitalises each word and leaves inner caps alone', () {
      expect(titleCase('ada of the ashen keep'), 'Ada Of The Ashen Keep');
      expect(titleCase('jean-luc mcKay'), 'Jean-Luc McKay');
      expect(titleCase('élodie'), 'Élodie');
    });

    test('dossierSummary takes the first sentence past the 30-char floor', () {
      Dossier dossier(String overview) => Dossier.fromJson({'overview': overview});
      expect(dossierSummary(null), '');
      expect(dossierSummary(dossier('')), '');
      expect(
        dossierSummary(dossier('Dr. Kellas is the village physician and its only sceptic. He arrives late.')),
        'Dr. Kellas is the village physician and its only sceptic.',
      );
      expect(dossierSummary(dossier('Short one. No terminator past thirty chars')), 'Short one. No terminator past thirty chars');
      expect(dossierSummary(dossier('  A place where the marsh meets the sea!  ')), 'A place where the marsh meets the sea!');
    });

    test('chapterLabel strips the extension, chapterCount agrees in number', () {
      expect(chapterLabel('Chapter 4.md'), 'Chapter 4');
      expect(chapterLabel('Chapter 4.MD'), 'Chapter 4');
      expect(chapterCount(1), '1 chapter');
      expect(chapterCount(3), '3 chapters');
    });

    test('bibleStats counts visible entities, characters, dossiers and portraits', () {
      final withPortrait = BibleEntity.fromJson({
        ..._entity('Ada', mentions: 1).raw,
        'image_asset_id': 'asset-1',
      });
      final stats = bibleStats(
        [withPortrait, _entity('Keep', type: BibleEntityType.place), _entity('Ghost', hidden: true)],
        {'ada': Dossier.fromJson({'overview': 'x'})},
      );
      expect(stats.entities, 2);
      expect(stats.characters, 1);
      expect(stats.dossiers, 1);
      expect(stats.portraits, 1);
      expect(stats.line, '2 entities · 1 character · 1 dossier · 1 portrait');
    });
  });
}
