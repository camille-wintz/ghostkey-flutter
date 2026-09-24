import '../core/chapter_reorder.dart';
import '../core/chapter_search.dart';
import '../core/words.dart';
import '../server/dto/plan.dart';
import '../server/dto/projects.dart';

// A chapter proposal, reviewed: what each proposed chapter is against the
// book that exists, the one "start from the existing text" question, and the
// edits the author makes to the list before it becomes a draft. Pure — every
// edit is a new tree, which the review sends whole.

/// What a proposed chapter is, against the book that exists. A view, not a
/// stored field.
enum ChapterStatus {
  written('Already written'),
  kept('Not in your outline'),
  fresh('To be written');

  const ChapterStatus(this.label);
  final String label;
}

/// Read in this order on purpose: a chapter the outline never asked for is
/// answering a different question than a beat that happens to be written
/// already, however strong its match.
ChapterStatus chapterStatus(ProposalChapter chapter) {
  if (chapter.origin == ProposalOrigin.existing) return ChapterStatus.kept;
  return chapter.match != null ? ChapterStatus.written : ChapterStatus.fresh;
}

/// What the match line calls the chapter it found.
String matchLabel(ProposalChapter chapter) {
  if (chapter.origin == ProposalOrigin.existing) return 'Existing chapter, unmatched';
  return chapter.match?.confidence == 'strong' ? 'Matched existing chapter' : 'Possible match';
}

/// One filter chip: all, or one status, with its count.
typedef StatusFilter = ({ChapterStatus? status, int count});

/// The chips over the list — all, then each status the proposal has.
List<StatusFilter> statusFilters(List<ProposalChapter> chapters) {
  final counts = {for (final s in ChapterStatus.values) s: 0};
  for (final c in chapters) {
    counts[chapterStatus(c)] = counts[chapterStatus(c)]! + 1;
  }
  return [
    (status: null, count: chapters.length),
    for (final s in ChapterStatus.values)
      if (counts[s]! > 0) (status: s, count: counts[s]!),
  ];
}

/// The one question for the whole list: do the new chapters open on the words
/// that already exist? Mixed is a real answer.
class CarryState {
  const CarryState({required this.carried, required this.carryable, required this.hint});
  final int carried;
  final int carryable;
  final String hint;

  bool get checked => carryable > 0 && carried == carryable;
  bool get mixed => carried > 0 && carried < carryable;
  bool get applies => carryable > 0;
}

CarryState carryState(int carried, int carryable, {String mixedSuffix = ''}) => CarryState(
      carried: carried,
      carryable: carryable,
      hint: carryable == 0
          ? 'nothing here has text to keep'
          : carried == 0
              ? 'every chapter starts blank'
              : carried == carryable
                  ? '$carried ${carried == 1 ? 'chapter keeps its' : 'chapters keep their'} words'
                  : '$carried of $carryable keep their words$mixedSuffix',
    );

CarryState proposalCarry(List<ProposalChapter> chapters) {
  final carryable = chapters.where((c) => c.match != null).toList();
  return carryState(carryable.where((c) => c.copyProse).length, carryable.length);
}

/// Every chapter rewritten, the parts left as they are.
List<ProposalEntry> mapChapters(List<ProposalEntry> entries, ProposalChapter Function(ProposalChapter) fn) => [
      for (final entry in entries)
        switch (entry) {
          ProposalChapter() => fn(entry),
          ProposalPart() => entry.copyWith(chapters: entry.chapters.map(fn).toList()),
        },
    ];

/// A card left in the list is written against the chapter it names, so a
/// match is its own acceptance — the stored row is brought into line with
/// what the list already says.
List<ProposalEntry> acceptMatches(List<ProposalEntry> entries) =>
    mapChapters(entries, (c) => c.match != null && !c.useAsReference ? c.copyWith(useAsReference: true) : c);

bool hasUnacceptedMatches(List<ProposalEntry> entries) =>
    proposalChapters(entries).any((c) => c.match != null && !c.useAsReference);

/// The carry answer written over every chapter that has text to carry. Mixed
/// reads as "not yet all of them", so the caller's toggle turns it on.
List<ProposalEntry> withCarry(List<ProposalEntry> entries, bool on) =>
    mapChapters(acceptMatches(entries), (c) => c.match != null ? c.copyWith(copyProse: on) : c);

/// One chapter rewritten wherever it sits.
List<ProposalEntry> patchChapter(List<ProposalEntry> entries, String id, ProposalChapter Function(ProposalChapter) fn) =>
    mapChapters(entries, (c) => c.id == id ? fn(c) : c);

/// Where a removed chapter was, so putting it back lands it there.
typedef DroppedChapter = ({ProposalChapter chapter, String? partId, int index});

DroppedChapter? locateChapter(List<ProposalEntry> entries, String id) {
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    switch (entry) {
      case ProposalChapter() when entry.id == id:
        return (chapter: entry, partId: null, index: i);
      case ProposalPart():
        final at = entry.chapters.indexWhere((c) => c.id == id);
        if (at >= 0) return (chapter: entry.chapters[at], partId: entry.id, index: at);
      case ProposalChapter():
    }
  }
  return null;
}

List<ProposalEntry> withoutChapter(List<ProposalEntry> entries, String id) => [
      for (final entry in entries)
        switch (entry) {
          ProposalChapter() when entry.id == id => null,
          ProposalChapter() => entry,
          ProposalPart() => entry.copyWith(chapters: entry.chapters.where((c) => c.id != id).toList()),
        },
    ].nonNulls.toList();

/// Put a chapter back where it was taken from — at the top level when its
/// part has gone since.
List<ProposalEntry> insertChapter(List<ProposalEntry> entries, DroppedChapter dropped) {
  final part = dropped.partId;
  if (part != null && entries.any((e) => e is ProposalPart && e.id == part)) {
    return [
      for (final entry in entries)
        if (entry is ProposalPart && entry.id == part)
          entry.copyWith(
            chapters: [...entry.chapters]..insert(dropped.index.clamp(0, entry.chapters.length), dropped.chapter),
          )
        else
          entry,
    ];
  }
  return [...entries]..insert(dropped.index.clamp(0, entries.length), dropped.chapter);
}

/// Put back every chapter dropped this session, oldest first, so each one's
/// remembered place is the place it goes back into.
List<ProposalEntry> restoreChapters(List<ProposalEntry> entries, List<DroppedChapter> dropped) =>
    dropped.fold(entries, insertChapter);

List<ProposalEntry> appendChapter(List<ProposalEntry> entries, ProposalChapter chapter) => [...entries, chapter];

List<ProposalEntry> appendPart(List<ProposalEntry> entries, ProposalPart part) => [...entries, part];

List<ProposalEntry> renamePart(List<ProposalEntry> entries, String partId, String name) => [
      for (final entry in entries) entry is ProposalPart && entry.id == partId ? entry.copyWith(name: name) : entry,
    ];

/// The part goes; its chapters stand in its place.
List<ProposalEntry> removePart(List<ProposalEntry> entries, String partId) => [
      for (final entry in entries)
        if (entry is ProposalPart && entry.id == partId) ...entry.chapters else entry,
    ];

/// "Part 3" — the first number no part is using.
String newPartName(List<ProposalEntry> entries) {
  final parts = entries.whereType<ProposalPart>().map((p) => p.name).toSet();
  for (var n = parts.length + 1;; n++) {
    final name = 'Part $n';
    if (!parts.contains(name)) return name;
  }
}

/// One row of the proposal as it is drawn.
sealed class ProposalRow {
  const ProposalRow();
  String get id;
}

class ProposalPartRow extends ProposalRow {
  const ProposalPartRow(this.part, {required this.collapsed});
  final ProposalPart part;
  final bool collapsed;

  @override
  String get id => part.id;
}

class ProposalChapterRow extends ProposalRow {
  const ProposalChapterRow(this.chapter, {required this.number, required this.nested});
  final ProposalChapter chapter;

  /// Its place in the whole proposal — what the author is numbering.
  final int number;
  final bool nested;

  @override
  String get id => chapter.id;
}

/// The proposal flattened for drawing: parts in place with their chapters
/// under them (none under a collapsed part), and only the chapters [visible]
/// keeps. A part a filter has emptied drops off with its chapters.
List<ProposalRow> proposalRows(
  List<ProposalEntry> entries, {
  required bool Function(String partId) isCollapsed,
  bool Function(ProposalChapter)? visible,
}) {
  final shown = visible ?? (_) => true;
  final filtering = visible != null;
  var number = 0;
  final rows = <ProposalRow>[];
  for (final entry in entries) {
    switch (entry) {
      case ProposalChapter():
        number++;
        if (shown(entry)) rows.add(ProposalChapterRow(entry, number: number, nested: false));
      case ProposalPart():
        final collapsed = isCollapsed(entry.id);
        final chapters = <ProposalRow>[];
        for (final c in entry.chapters) {
          number++;
          if (!collapsed && shown(c)) chapters.add(ProposalChapterRow(c, number: number, nested: true));
        }
        if (filtering && chapters.isEmpty) continue;
        rows.add(ProposalPartRow(entry, collapsed: collapsed));
        rows.addAll(chapters);
    }
  }
  return rows;
}

/// The proposal after the chapter drawn at row [from] is dropped at row [to]
/// (the rows unfiltered). Where it lands decides its part, by the manuscript
/// list's own rule (`moveChapterRow`) — the two lists drag alike.
List<ProposalEntry> moveProposalRow(
  List<ProposalEntry> entries,
  List<ProposalRow> rows,
  int from,
  int to,
  bool Function(String partId) isCollapsed,
) {
  final byId = {for (final c in proposalChapters(entries)) c.id: c};
  final parts = {for (final p in entries.whereType<ProposalPart>()) p.id: p};
  final moved = moveChapterRow(
    _asTree(entries),
    [
      for (final row in rows)
        switch (row) {
          ProposalPartRow(:final part) => FolderRow(id: part.id, name: part.name),
          ProposalChapterRow(:final chapter, :final nested) => ChapterRow(_asDoc(chapter), nested: nested),
        },
    ],
    from,
    to,
    isCollapsed,
  );
  return [
    for (final entry in moved)
      switch (entry) {
        DocumentSummary() => byId[entry.id]!,
        ChapterGroup() => parts[entry.id]!.copyWith(chapters: [for (final d in entry.chapters) byId[d.id]!]),
      },
  ];
}

// The drag math is the manuscript list's; a proposal rides it by standing its
// chapters in for documents, by id, and is rebuilt from the ids afterwards.
List<ChaptersListEntry> _asTree(List<ProposalEntry> entries) => [
      for (final entry in entries)
        switch (entry) {
          ProposalChapter() => _asDoc(entry),
          ProposalPart() => ChapterGroup(id: entry.id, name: entry.name, chapters: entry.chapters.map(_asDoc).toList()),
        },
    ];

DocumentSummary _asDoc(ProposalChapter chapter) => DocumentSummary(
      id: chapter.id,
      kind: DocumentKind.chapter,
      filename: chapter.title,
      version: 0,
      wordCount: null,
      updatedAt: '',
    );

/// A chapter the book has that no card in the proposal claims — one the
/// author can put back. Empty while the matches are stale: those ids belong
/// to another draft.
List<DocumentSummary> unclaimedChapters(List<ChaptersListEntry> tree, List<ProposalEntry> entries, {required bool matchesStale}) {
  if (matchesStale) return const [];
  final claimed = {for (final c in proposalChapters(entries)) ?c.match?.documentId};
  return [for (final doc in chaptersInTree(tree)) if (!claimed.contains(doc.id)) doc];
}

/// A card put back from the manuscript: kept whole as a reference, carrying
/// its words when the rest of the list does.
ProposalChapter chapterFromManuscript(DocumentSummary doc, {required String id, required bool carry}) =>
    ProposalChapter.added(
      id: id,
      title: doc.label,
      copyProse: carry,
      match: ProposalMatch(
        documentId: doc.id,
        filename: doc.filename,
        words: doc.wordCount ?? 0,
        confidence: 'strong',
        reason: 'You added this one from the manuscript yourself.',
      ),
    );

/// A length in the narrow column that carries it. Zero is "not known" as
/// often as "empty", so it reads as a dash.
String wordLabel(int? words) => words != null && words > 0 ? '${formatWords(words)} w' : '—';
