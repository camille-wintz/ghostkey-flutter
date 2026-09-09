import '../server/dto/projects.dart';

/// One row of the chapter list as it is drawn: a folder heading, or a chapter
/// that may sit inside one.
sealed class ChapterListRow {
  const ChapterListRow();
}

class FolderRow extends ChapterListRow {
  const FolderRow(this.name);
  final String name;
}

class ChapterRow extends ChapterListRow {
  const ChapterRow(this.doc, {required this.nested});
  final DocumentSummary doc;
  final bool nested;

  ChapterRow withNested(bool value) => ChapterRow(doc, nested: value);
}

/// The chapter tree flattened for drawing, filtered by what was typed.
///
/// An empty query gives the tree: folders in place, their chapters nested
/// under them, collapsed ones contributing only their heading. A query gives
/// matches only, flat and unnested.
List<ChapterListRow> filterChapterTree(
  List<ChaptersListEntry> tree,
  String query,
  bool Function(String folder) isCollapsed,
) {
  final needle = fold(query);
  final rows = <ChapterListRow>[];
  for (final entry in tree) {
    switch (entry) {
      case DocumentSummary():
        if (matchesQuery(entry.label, query)) rows.add(ChapterRow(entry, nested: false));
      case ChapterGroup():
        if (needle.isNotEmpty) {
          for (final doc in entry.chapters) {
            if (matchesQuery(doc.label, query)) rows.add(ChapterRow(doc, nested: false));
          }
          continue;
        }
        rows.add(FolderRow(entry.name));
        if (isCollapsed(entry.name)) continue;
        for (final doc in entry.chapters) {
          rows.add(ChapterRow(doc, nested: true));
        }
    }
  }
  return rows;
}

/// Does a title match what was typed? The one place that decides, so the
/// chapter list and the note list can never disagree about it. Case- and
/// accent-insensitive: an author searching a French manuscript should not have
/// to reproduce the diacritics to find their own chapter.
bool matchesQuery(String title, String query) {
  final needle = fold(query);
  return needle.isEmpty || fold(title).contains(needle);
}

/// Lowercased and stripped of diacritics. Dart has no Unicode normalisation in
/// the core library, so the accents are folded by table: Latin-1 and Latin
/// Extended-A, which is every letter the languages this app is written in
/// use. A character outside the table folds to itself.
String fold(String value) {
  final lower = value.trim().toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_folds[ch] ?? ch);
  }
  return out.toString();
}

const Map<String, String> _folds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'æ': 'ae',
  'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c',
  'ď': 'd', 'đ': 'd', 'ð': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
  'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g',
  'ĥ': 'h', 'ħ': 'h',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i', 'ı': 'i',
  'ĵ': 'j',
  'ķ': 'k',
  'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ŀ': 'l', 'ł': 'l',
  'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o',
  'œ': 'oe',
  'ŕ': 'r', 'ŗ': 'r', 'ř': 'r',
  'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's', 'ß': 'ss',
  'ţ': 't', 'ť': 't', 'ŧ': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
  'ŵ': 'w',
  'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
  'þ': 'th',
};
