import 'json.dart';

// The author's plan: their boards (StoryMap, authored rows), the story
// structures a board can be started on (StoryTemplate), and the Outline row
// (AuthoredOutline) — the prose, and the chapter proposal or changeset the
// chat wrote from a plan. Mara reads all of it; the chat's Review reads the
// same shapes.
//
// Every class that is written back keeps its `raw` JSON, so a write echoes
// fields this client never reads (a proposal card's cast, say) rather than
// dropping them — the server passes them through verbatim.

/// One card of a board. `kind: label` is a heading, not a beat. `cards` is
/// only ever filled on boards saved before the plan went flat; readers
/// flatten it (`StoryMap.cards`).
class StoryCard {
  const StoryCard({
    required this.id,
    required this.title,
    required this.description,
    required this.isLabel,
    required this.chapters,
    required this.cards,
    this.key,
  });
  final String id;

  /// The template beat this card answers — what finds its hint. Lineage
  /// only; a card the author wrote has none.
  final String? key;
  final String title;
  final String description;
  final bool isLabel;
  final List<String> chapters;
  final List<StoryCard> cards;

  static StoryCard fromJson(Json json) => StoryCard(
        id: asString(json['id']),
        key: json['key'] as String?,
        title: asString(json['title']),
        description: asString(json['description']),
        isLabel: json['kind'] == 'label',
        chapters: asStringList(json['chapters']),
        cards: asJsonList(json['cards']).map(StoryCard.fromJson).toList(),
      );
}

class StoryMap {
  const StoryMap({
    required this.id,
    required this.name,
    required this.source,
    required this.nodes,
    this.templateId,
    this.roots = const [],
  });
  final String id;

  /// Which structure the board is on; null on a blank board. Lineage only —
  /// it finds the template's name and hints, and nothing branches on it.
  final String? templateId;

  /// The author's own name; null takes the structure's.
  final String? name;

  /// `authored` (a board) or `derived` (the book_map job's cache).
  final String source;
  final List<StoryCard> nodes;

  /// The cards that head a chain beyond the ones the order already heads
  /// (`layout.roots`). Empty when the row carries no layout.
  final List<String> roots;

  bool get authored => source == 'authored';

  /// Every card, one level, in reading order — a board saved before the plan
  /// went flat reads its nested cards after the card holding them.
  List<StoryCard> get cards => [for (final card in nodes) ..._flatten(card)];

  static Iterable<StoryCard> _flatten(StoryCard card) sync* {
    yield card;
    for (final child in card.cards) {
      yield* _flatten(child);
    }
  }

  static StoryMap fromJson(Json json) => StoryMap(
        id: asString(json['id']),
        templateId: json['template_id'] as String?,
        name: json['name'] as String?,
        source: asString(json['source']),
        nodes: asJsonList(json['nodes']).map(StoryCard.fromJson).toList(),
        roots: json['layout'] is Map ? asStringList(asJson(json['layout'])['roots']) : const [],
      );
}

/// What a board is called: its own name, else its structure's, else the
/// standing name of a blank board nobody named. The server's `boardTitle`
/// says the same, so the chat and the list call a board one thing.
String boardTitle(StoryMap board, String? structureName) => board.name ?? structureName ?? 'Untitled board';

/// A write that added a card: the board as it stands, and the new card.
typedef StoryCardWrite = ({StoryMap board, String cardId});

class TemplateBeat {
  const TemplateBeat({required this.key, required this.label, required this.hint});
  final String key;
  final String label;

  /// The question the beat answers — an unfilled card's placeholder.
  final String hint;

  static TemplateBeat fromJson(Json json) => TemplateBeat(
        key: asString(json['key']),
        label: asString(json['label']),
        hint: asString(json['hint']),
      );
}

class TemplateNode {
  const TemplateNode({required this.key, required this.title, required this.beats});
  final String key;
  final String title;
  final List<TemplateBeat> beats;

  static TemplateNode fromJson(Json json) => TemplateNode(
        key: asString(json['key']),
        title: asString(json['title']),
        beats: asJsonList(json['beats']).map(TemplateBeat.fromJson).toList(),
      );
}

/// A story structure a board can be started on. Clients draw its name and
/// description and never branch on its id.
class StoryTemplate {
  const StoryTemplate({
    required this.id,
    required this.name,
    required this.tradition,
    required this.description,
    required this.nodes,
  });
  final String id;
  final String name;
  final String tradition;
  final String description;
  final List<TemplateNode> nodes;

  /// Beat key → hint, for the cards that answer this structure's beats.
  Map<String, String> get hints => {
        for (final node in nodes)
          for (final beat in node.beats) beat.key: beat.hint,
      };

  static StoryTemplate fromJson(Json json) => StoryTemplate(
        id: asString(json['id']),
        name: asString(json['name']),
        tradition: asString(json['tradition']),
        description: asString(json['description']),
        nodes: asJsonList(json['nodes']).map(TemplateNode.fromJson).toList(),
      );
}

/// Which plan a proposal was read from: the prose outline, or one board.
/// Null on the wire (a row from before the field) reads as prose.
class PlanRef {
  const PlanRef.prose() : mapId = null;
  const PlanRef.board(String this.mapId);

  /// The board's id when the proposal was read from a board.
  final String? mapId;

  bool get isProse => mapId == null;

  static PlanRef fromJson(Object? json) {
    if (json is Map && json['kind'] == 'map' && json['map_id'] is String) return PlanRef.board(json['map_id'] as String);
    return const PlanRef.prose();
  }
}

/// Which existing chapter a proposed one corresponds to. Advisory: a card
/// left in the list is written against it.
class ProposalMatch {
  const ProposalMatch({
    required this.documentId,
    required this.filename,
    required this.words,
    required this.confidence,
    required this.reason,
  });
  final String documentId;
  final String filename;
  final int words;

  /// `strong` or `possible`.
  final String confidence;

  /// One line for the author, rendered as-is.
  final String reason;

  static ProposalMatch fromJson(Json json) => ProposalMatch(
        documentId: asString(json['document_id']),
        filename: asString(json['filename']),
        words: asInt(json['words']),
        confidence: asString(json['confidence'], 'possible'),
        reason: asString(json['reason']),
      );

  Json toJson() => {
        'document_id': documentId,
        'filename': filename,
        'words': words,
        'confidence': confidence,
        'reason': reason,
      };
}

/// Where a proposed chapter came from: the outline asked for it (`outline`),
/// the outline asked and a written chapter covers it (`both`), or the book
/// has it and the outline never mentions it (`existing`).
enum ProposalOrigin {
  outline,
  existing,
  both;

  static ProposalOrigin fromWire(String? value) => switch (value) {
        'existing' => ProposalOrigin.existing,
        'both' => ProposalOrigin.both,
        _ => ProposalOrigin.outline,
      };
}

/// One entry of a chapter proposal: a chapter, or a part holding chapters.
sealed class ProposalEntry {
  String get id;
  Json toJson();
}

ProposalEntry proposalEntryFromJson(Json json) =>
    json['name'] is String && json['chapters'] is List ? ProposalPart.fromJson(json) : ProposalChapter.fromJson(json);

/// One proposed chapter. Nothing exists until a commit.
class ProposalChapter implements ProposalEntry {
  const ProposalChapter({
    required this.id,
    required this.title,
    required this.notes,
    required this.origin,
    required this.useAsReference,
    required this.copyProse,
    required this.raw,
    this.words,
    this.match,
  });

  @override
  final String id;
  final String title;
  final String notes;

  /// The plan's length target for the chapter, when it gave one.
  final int? words;
  final ProposalOrigin origin;
  final ProposalMatch? match;
  final bool useAsReference;
  final bool copyProse;
  final Json raw;

  static ProposalChapter fromJson(Json json) => ProposalChapter(
        id: asString(json['id']),
        title: asString(json['title']),
        notes: asString(json['notes']),
        words: json['words'] is num ? asInt(json['words']) : null,
        origin: ProposalOrigin.fromWire(json['origin'] as String?),
        match: json['match'] is Map ? ProposalMatch.fromJson(asJson(json['match'])) : null,
        useAsReference: asBool(json['use_as_reference']),
        copyProse: asBool(json['copy_prose']),
        raw: json,
      );

  /// A chapter the author adds by hand: blank, or put back from the
  /// manuscript as a reference.
  factory ProposalChapter.added({
    required String id,
    String title = '',
    ProposalMatch? match,
    bool copyProse = false,
  }) =>
      ProposalChapter.fromJson({
        'id': id,
        'title': title,
        'notes': '',
        'origin': match == null ? 'outline' : 'existing',
        'match': match?.toJson(),
        'use_as_reference': match != null,
        'copy_prose': match != null && copyProse,
      });

  ProposalChapter copyWith({String? title, String? notes, bool? useAsReference, bool? copyProse}) {
    final next = Map<String, dynamic>.from(raw);
    if (title != null) next['title'] = title;
    if (notes != null) next['notes'] = notes;
    if (useAsReference != null) next['use_as_reference'] = useAsReference;
    if (copyProse != null) next['copy_prose'] = copyProse;
    return ProposalChapter.fromJson(next);
  }

  @override
  Json toJson() => raw;
}

/// One part of the plan and the proposed chapters in it. Committing makes a
/// folder with this id and name.
class ProposalPart implements ProposalEntry {
  const ProposalPart({required this.id, required this.name, required this.chapters, required this.raw});

  @override
  final String id;
  final String name;
  final List<ProposalChapter> chapters;
  final Json raw;

  static ProposalPart fromJson(Json json) => ProposalPart(
        id: asString(json['id']),
        name: asString(json['name']),
        chapters: asJsonList(json['chapters']).map(ProposalChapter.fromJson).toList(),
        raw: json,
      );

  factory ProposalPart.fresh({required String id, required String name}) =>
      ProposalPart(id: id, name: name, chapters: const [], raw: {'id': id, 'name': name, 'chapters': const <Json>[]});

  ProposalPart copyWith({String? name, List<ProposalChapter>? chapters}) => ProposalPart(
        id: id,
        name: name ?? this.name,
        chapters: chapters ?? this.chapters,
        raw: raw,
      );

  @override
  Json toJson() => {...raw, 'id': id, 'name': name, 'chapters': chapters.map((c) => c.toJson()).toList()};
}

/// Every proposed chapter, parts flattened, in reading order.
List<ProposalChapter> proposalChapters(List<ProposalEntry> entries) => [
      for (final entry in entries)
        ...switch (entry) {
          ProposalChapter() => [entry],
          ProposalPart() => entry.chapters,
        },
    ];

/// One existing chapter an op points at.
class ChangesetChapterRef {
  const ChangesetChapterRef({required this.documentId, required this.filename, this.words});
  final String documentId;
  final String filename;
  final int? words;

  static ChangesetChapterRef fromJson(Json json) => ChangesetChapterRef(
        documentId: asString(json['document_id']),
        filename: asString(json['filename']),
        words: json['words'] is num ? asInt(json['words']) : null,
      );
}

/// One chapter an op writes. `from` is the existing chapter it retells.
class ChangesetNewChapter {
  const ChangesetNewChapter({required this.title, required this.notes, required this.raw, this.from});
  final String title;
  final String notes;
  final ChangesetChapterRef? from;
  final Json raw;

  /// Who and what it is about, by name — read-only here.
  List<String> get cast => [
        for (final e in asJsonList(raw['entities']))
          if (asString(e['name']).isNotEmpty) asString(e['name']),
      ];

  static ChangesetNewChapter fromJson(Json json) => ChangesetNewChapter(
        title: asString(json['title']),
        notes: asString(json['notes']),
        from: json['from'] is Map ? ChangesetChapterRef.fromJson(asJson(json['from'])) : null,
        raw: json,
      );

  ChangesetNewChapter withText({String? title, String? notes}) =>
      ChangesetNewChapter.fromJson({...raw, 'title': ?title, 'notes': ?notes});

  Json toJson() => raw;
}

/// One proposed change to the written book. Every chapter no op names is
/// kept, whole.
sealed class ChangesetOp {
  const ChangesetOp({required this.id, required this.reason, required this.raw});
  final String id;

  /// Addressed to the author, rendered as-is.
  final String reason;
  final Json raw;

  /// Null for an op this build does not know — it is left out of the review
  /// rather than drawn wrong.
  static ChangesetOp? fromJson(Json json) => switch (json['op']) {
        'remove' => ChangesetRemove.fromJson(json),
        'add' => ChangesetAdd.fromJson(json),
        'rewrite' => ChangesetRewrite.fromJson(json),
        _ => null,
      };

  Json toJson() => raw;
}

class ChangesetRemove extends ChangesetOp {
  const ChangesetRemove({required super.id, required super.reason, required super.raw, required this.chapters});
  final List<ChangesetChapterRef> chapters;

  static ChangesetRemove fromJson(Json json) => ChangesetRemove(
        id: asString(json['id']),
        reason: asString(json['reason']),
        raw: json,
        chapters: asJsonList(json['chapters']).map(ChangesetChapterRef.fromJson).toList(),
      );
}

/// An op that writes chapters: an add or a rewrite.
sealed class ChangesetWrite extends ChangesetOp {
  const ChangesetWrite({required super.id, required super.reason, required super.raw, required this.written});

  /// The chapters it writes, in reading order (the wire's `with`).
  final List<ChangesetNewChapter> written;

  /// The op with its written chapters replaced — the author's edits, folded
  /// in before an apply.
  ChangesetWrite withWritten(List<ChangesetNewChapter> next);
}

class ChangesetAdd extends ChangesetWrite {
  const ChangesetAdd({
    required super.id,
    required super.reason,
    required super.raw,
    required super.written,
    this.after,
    this.folder,
  });

  /// The chapter the new ones follow; null is the head of the book.
  final ChangesetChapterRef? after;

  /// The part the new chapters land in, by name — display only.
  final String? folder;

  static ChangesetAdd fromJson(Json json) => ChangesetAdd(
        id: asString(json['id']),
        reason: asString(json['reason']),
        raw: json,
        written: asJsonList(json['with']).map(ChangesetNewChapter.fromJson).toList(),
        after: json['after'] is Map ? ChangesetChapterRef.fromJson(asJson(json['after'])) : null,
        folder: json['folder'] as String?,
      );

  @override
  ChangesetAdd withWritten(List<ChangesetNewChapter> next) =>
      ChangesetAdd.fromJson({...raw, 'with': next.map((c) => c.toJson()).toList()});
}

class ChangesetRewrite extends ChangesetWrite {
  const ChangesetRewrite({
    required super.id,
    required super.reason,
    required super.raw,
    required super.written,
    required this.chapters,
  });

  /// The stretch being retold, in book order.
  final List<ChangesetChapterRef> chapters;

  static ChangesetRewrite fromJson(Json json) => ChangesetRewrite(
        id: asString(json['id']),
        reason: asString(json['reason']),
        raw: json,
        written: asJsonList(json['with']).map(ChangesetNewChapter.fromJson).toList(),
        chapters: asJsonList(json['chapters']).map(ChangesetChapterRef.fromJson).toList(),
      );

  @override
  ChangesetRewrite withWritten(List<ChangesetNewChapter> next) =>
      ChangesetRewrite.fromJson({...raw, 'with': next.map((c) => c.toJson()).toList()});
}

/// The diff stat of a changeset, counted server-side.
class ChangesetLedger {
  const ChangesetLedger({
    required this.chaptersBefore,
    required this.chaptersAfter,
    required this.wordsBefore,
    required this.wordsAfter,
    required this.removedChapters,
    required this.rewrittenChapters,
    required this.writtenChapters,
    required this.charactersLeaving,
  });
  final int chaptersBefore;
  final int chaptersAfter;
  final int wordsBefore;

  /// An estimate: every written chapter is priced at the median.
  final int wordsAfter;
  final int removedChapters;
  final int rewrittenChapters;
  final int writtenChapters;
  final List<String> charactersLeaving;

  static ChangesetLedger fromJson(Json json) => ChangesetLedger(
        chaptersBefore: asInt(json['chapters_before']),
        chaptersAfter: asInt(json['chapters_after']),
        wordsBefore: asInt(json['words_before']),
        wordsAfter: asInt(json['words_after']),
        removedChapters: asInt(json['removed_chapters']),
        rewrittenChapters: asInt(json['rewritten_chapters']),
        writtenChapters: asInt(json['written_chapters']),
        charactersLeaving: asStringList(json['characters_leaving']),
      );
}

/// What the read-back said about the changeset that shipped.
class ChangesetVerdict {
  const ChangesetVerdict({required this.ok, required this.problems});
  final bool ok;
  final List<String> problems;

  static ChangesetVerdict fromJson(Json json) =>
      ChangesetVerdict(ok: asBool(json['ok'], true), problems: asStringList(json['problems']));
}

/// How the author's request changes the book in hand, awaiting review.
class Changeset {
  const Changeset({
    required this.summary,
    required this.questions,
    required this.ops,
    this.ledger,
    this.verdict,
  });
  final String summary;
  final List<String> questions;
  final List<ChangesetOp> ops;
  final ChangesetLedger? ledger;
  final ChangesetVerdict? verdict;

  static Changeset fromJson(Json json) => Changeset(
        summary: asString(json['summary']),
        questions: asStringList(json['questions']),
        ops: asJsonList(json['ops']).map(ChangesetOp.fromJson).nonNulls.toList(),
        ledger: json['ledger'] is Map ? ChangesetLedger.fromJson(asJson(json['ledger'])) : null,
        verdict: json['verdict'] is Map ? ChangesetVerdict.fromJson(asJson(json['verdict'])) : null,
      );
}

/// The Outline row: the author's prose, and whatever the chat proposed from
/// a plan — a list of chapters, or a changeset over the book — until it is
/// committed, applied or dismissed.
class AuthoredOutline {
  const AuthoredOutline({
    required this.text,
    this.chapters = const [],
    this.matchedDraftId,
    this.brokenFrom = const PlanRef.prose(),
    this.committedDraftId,
    this.changeset,
    this.changesetDraftId,
    this.intent = '',
  });

  /// The author's outline, markdown. Empty until they write one.
  final String text;

  /// The proposal, parts and chapters. Empty once committed or dismissed.
  final List<ProposalEntry> chapters;

  /// The draft the proposal's matches point into.
  final String? matchedDraftId;

  /// The plan the last proposal was read from.
  final PlanRef brokenFrom;

  /// The draft the last proposal became.
  final String? committedDraftId;
  final Changeset? changeset;

  /// The draft the changeset's ops point into.
  final String? changesetDraftId;

  /// What the author said is changing, as the chat wrote it down.
  final String intent;

  /// A proposal or a changeset is waiting on the Chapters page.
  bool get pending => chapters.isNotEmpty || changeset != null;

  static AuthoredOutline fromJson(Json json) => AuthoredOutline(
        text: asString(json['text']),
        chapters: asJsonList(json['chapters']).map(proposalEntryFromJson).toList(),
        matchedDraftId: json['matched_draft_id'] as String?,
        brokenFrom: PlanRef.fromJson(json['broken_from']),
        committedDraftId: json['committed_draft_id'] as String?,
        changeset: json['changeset'] is Map ? Changeset.fromJson(asJson(json['changeset'])) : null,
        changesetDraftId: json['changeset_draft_id'] as String?,
        intent: asString(json['intent']),
      );
}

/// A chapter a commit created, with what the plan row it owes carries.
class CommittedChapter {
  const CommittedChapter({required this.documentId, required this.filename, required this.notes, this.words});
  final String documentId;
  final String filename;
  final String notes;

  /// The card's length target — the plan row's `target_words`.
  final int? words;

  static CommittedChapter fromJson(Json json) => CommittedChapter(
        documentId: asString(json['document_id']),
        filename: asString(json['filename']),
        notes: asString(json['notes']),
        words: json['words'] is num ? asInt(json['words']) : null,
      );
}

/// POST /authored-outline/commit: the new draft and the chapters made in it,
/// in proposal order.
class CommitResult {
  const CommitResult({required this.draftName, required this.chapters});
  final String draftName;
  final List<CommittedChapter> chapters;

  static CommitResult fromJson(Json json) => CommitResult(
        draftName: asString(asJson(json['draft'])['name']),
        chapters: asJsonList(json['chapters']).map(CommittedChapter.fromJson).toList(),
      );
}
