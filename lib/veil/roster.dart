import '../core/chapter_search.dart';
import '../server/dto/bible.dart';

// The roster as it is drawn, derived from the bible: pure, so the grouping,
// the sorting and the search can be tested without a device. Ported from
// the desktop's `useBibleFilters` / `useBibleOverview` / `types/bible.ts`;
// display helpers only, no author-layer folding (that is the server's job).

const List<BibleEntityType> _typeOrder = [
  BibleEntityType.character,
  BibleEntityType.place,
  BibleEntityType.term,
];

/// One book of the series as a tab.
class BookTab {
  const BookTab({required this.id, required this.label});
  final String id;
  final String label;
}

/// One type's block of the roster, sorted by presence.
class RosterGroup {
  const RosterGroup({required this.type, required this.entities});
  final BibleEntityType type;
  final List<BibleEntity> entities;
}

/// The roster under a search, a type tab and a book tab.
class RosterView {
  const RosterView({
    required this.groups,
    required this.shown,
    required this.total,
    required this.hidden,
    required this.peak,
  });

  /// Matching entities grouped by type, in character → place → term order.
  final List<RosterGroup> groups;
  final int shown;

  /// Visible entities before the search and the type tab — the "of N" the
  /// footer counts against, so filtering never looks like the bible shrank.
  final int total;
  final List<BibleEntity> hidden;

  /// The busiest entity under the current book: the scale every presence bar
  /// is drawn against. Never zero — it divides.
  final int peak;
}

/// Every book of the series, in reading order — empty for a standalone, the
/// tabs being worth their row only when there is something to switch between.
List<BookTab> bookTabs(List<BibleEntity> entities) {
  final seen = <String, String>{};
  for (final entity in entities) {
    for (final book in entity.books) {
      seen.putIfAbsent(book.projectId, () => book.title);
    }
  }
  if (seen.length < 2) return const [];
  return [for (final entry in seen.entries) BookTab(id: entry.key, label: entry.value)];
}

/// Does the entity answer to what was typed? Name, extracted name and every
/// alias, accent- and case-blind.
bool matchesEntity(BibleEntity entity, String query) {
  final needle = fold(query);
  if (needle.isEmpty) return true;
  return [entity.name, entity.extractedName, ...entity.aliases].any((form) => fold(form).contains(needle));
}

/// The roster filtered and grouped. `book` null is the "All" tab. Author-added
/// entities pass every book filter: they have no mentions anywhere until the
/// author writes them in, and filtering them out would read as the save
/// having failed.
RosterView buildRoster(
  List<BibleEntity> entities, {
  String query = '',
  BibleEntityType? type,
  String? book,
}) {
  final visible = entities.where((e) => !e.hidden).toList();
  final hidden = entities.where((e) => e.hidden).toList();

  final inBook = visible.where((e) => book == null || e.isUser || e.mentionsIn(book) > 0).toList();
  final matched = inBook.where((e) => matchesEntity(e, query) && (type == null || e.type == type)).toList();

  int presence(BibleEntity e) => e.mentionsIn(book);
  final groups = [
    for (final t in _typeOrder)
      RosterGroup(
        type: t,
        entities: matched.where((e) => e.type == t).toList()
          ..sort((a, b) {
            final byPresence = presence(b).compareTo(presence(a));
            // Folded, not lowercased: a code-point compare files Élodie
            // after Zed, which no author would call alphabetical.
            return byPresence != 0 ? byPresence : fold(a.name).compareTo(fold(b.name));
          }),
      ),
  ].where((g) => g.entities.isNotEmpty).toList();

  // Scaled against the book in view, not the whole series: a book-two cast
  // measured against a book-one protagonist would read as uniformly absent.
  var peak = 1;
  for (final e in inBook) {
    if (presence(e) > peak) peak = presence(e);
  }

  return RosterView(groups: groups, shown: matched.length, total: inBook.length, hidden: hidden, peak: peak);
}

/// An entity this book never mentions but a sibling does — drawn as the word
/// "series" rather than a bare 0 the author would take for a bug.
bool appearsElsewhere(BibleEntity entity, String projectId) =>
    entity.mentionCount == 0 && entity.books.any((b) => b.projectId != projectId && b.mentionCount > 0);

/// The presence bar's fill, 0–1. Floors at a sliver so a one-chapter walk-on
/// still reads as present rather than as missing data.
double presenceFraction(int count, int peak) {
  if (count <= 0) return 0;
  final fraction = count / (peak < 1 ? 1 : peak);
  return fraction < 0.06 ? 0.06 : (fraction > 1 ? 1 : fraction);
}

/// The bible in four numbers: entities, characters, dossiers written,
/// portraits — the one part of the desktop landing page that fits a phone.
class BibleStats {
  const BibleStats({required this.entities, required this.characters, required this.dossiers, required this.portraits});
  final int entities;
  final int characters;
  final int dossiers;
  final int portraits;

  String get line => [
        _count(entities, 'entity', 'entities'),
        _count(characters, 'character', 'characters'),
        _count(dossiers, 'dossier', 'dossiers'),
        _count(portraits, 'portrait', 'portraits'),
      ].join(' · ');
}

BibleStats bibleStats(List<BibleEntity> entities, Map<String, Dossier> dossiers) {
  final visible = entities.where((e) => !e.hidden);
  return BibleStats(
    entities: visible.length,
    characters: visible.where((e) => e.type == BibleEntityType.character).length,
    dossiers: visible.where((e) => dossiers.containsKey(e.key)).length,
    portraits: visible.where((e) => e.imageAssetId != null).length,
  );
}

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// "3 chapters" / "1 chapter".
String chapterCount(int n) => _count(n, 'chapter', 'chapters');

/// Display-only Title Case: the first letter of every whitespace- or
/// hyphen-separated word, the rest of each word untouched so intentional
/// caps (McKay) survive. The stored name is never changed.
String titleCase(String name) => name.replaceAllMapped(
      RegExp(r'(^|[\s-])(\p{L})', unicode: true),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    );

/// The dossier's one-line answer to "who is this": the opening sentence of
/// its overview. The 30-character floor before the terminator stops
/// "Dr. Kellas is…" cutting the line to two words; when nothing matches the
/// whole overview stands in and the caller's truncation handles it. No
/// dossier, no summary — the surfaces show nothing rather than invent one.
String dossierSummary(Dossier? dossier) {
  final overview = dossier?.overview.trim() ?? '';
  if (overview.isEmpty) return '';
  final match = RegExp(r'^.{30,}?[.!?](?=\s|$)').firstMatch(overview);
  return (match?.group(0) ?? overview).trim();
}

/// A chapter filename as a title: the `.md` dropped.
String chapterLabel(String filename) => filename.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
