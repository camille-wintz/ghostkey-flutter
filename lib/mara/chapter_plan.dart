import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../poltergeist/providers.dart';
import '../server/dto/plan.dart';
import '../server/dto/projects.dart';
import '../server/errors.dart';
import '../server/plan/api.dart';
import '../server/providers.dart';
import 'proposal.dart';
import 'providers.dart';

/// Which face the Chapters page shows. Decided by the row first — a
/// changeset or a proposal on it is the thing to look at, whatever the book
/// holds — and by the book only when the row is spent.
enum ChaptersMode { changeset, proposal, book, empty }

ChaptersMode chaptersMode(AuthoredOutline outline, List<ChaptersListEntry> tree) {
  if (outline.changeset != null) return ChaptersMode.changeset;
  if (outline.chapters.isNotEmpty) return ChaptersMode.proposal;
  return chaptersInTree(tree).isNotEmpty ? ChaptersMode.book : ChaptersMode.empty;
}

/// The line the plan says about itself, for the bar over it.
String chaptersStatusLine(AuthoredOutline outline, List<ChaptersListEntry> tree) {
  String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  if (outline.changeset case final changeset?) return '${count(changeset.ops.length, 'change', 'changes')} proposed';
  final proposed = proposalChapters(outline.chapters).length;
  if (proposed > 0) return '${count(proposed, 'chapter', 'chapters')} proposed';
  final chapters = chaptersInTree(tree).length;
  return chapters > 0 ? count(chapters, 'chapter', 'chapters') : '';
}

/// What a commit made, for the page to say once.
typedef CommitReceipt = ({int count, String draftName, String? firstFilename});

class ChapterPlanState {
  const ChapterPlanState({
    this.filter,
    this.dropped = const [],
    this.saving = false,
    this.committing = false,
    this.dismissing = false,
    this.applying = false,
    this.error,
    this.committed,
  });

  /// The status the proposal list is narrowed to; null shows all.
  final ChapterStatus? filter;

  /// Chapters dropped from the proposal this visit, oldest first — session
  /// undo, written the moment they went.
  final List<DroppedChapter> dropped;
  final bool saving;
  final bool committing;
  final bool dismissing;
  final bool applying;
  final String? error;
  final CommitReceipt? committed;

  ChapterPlanState copyWith({
    ChapterStatus? filter,
    bool clearFilter = false,
    List<DroppedChapter>? dropped,
    bool? saving,
    bool? committing,
    bool? dismissing,
    bool? applying,
    String? error,
    bool clearError = false,
    CommitReceipt? committed,
    bool clearCommitted = false,
  }) =>
      ChapterPlanState(
        filter: clearFilter ? null : (filter ?? this.filter),
        dropped: dropped ?? this.dropped,
        saving: saving ?? this.saving,
        committing: committing ?? this.committing,
        dismissing: dismissing ?? this.dismissing,
        applying: applying ?? this.applying,
        error: clearError ? null : (error ?? this.error),
        committed: clearCommitted ? null : (committed ?? this.committed),
      );
}

/// The Outline row's proposal and changeset, as the Chapters page writes
/// them: every edit to the proposal PUTs the whole tree (as the desk does),
/// one at a time, each built on the tree the last write answered with — so
/// two fields saved in a row never write each other's old words back. Then
/// the dismiss, the commit (and the plan rows it owes) and the changeset's
/// apply. The row is re-read after each; nothing is patched here.
class ChapterPlanWrites extends Notifier<ChapterPlanState> {
  ChapterPlanWrites(this.projectId);
  final String projectId;

  Future<void> _queue = Future.value();

  /// The row as the last write in this queue left it — the base the next
  /// queued edit builds on, until the re-read has caught up.
  AuthoredOutline? _written;
  int _pending = 0;

  @override
  ChapterPlanState build() => const ChapterPlanState();

  void setFilter(ChapterStatus? filter) =>
      state = filter == null ? state.copyWith(clearFilter: true) : state.copyWith(filter: filter);

  /// Change the proposal. [change] is handed the stored tree at the moment the
  /// write runs. Resolves false when the write did not land (the state says
  /// why).
  Future<bool> edit(List<ProposalEntry> Function(List<ProposalEntry> entries) change) {
    _pending++;
    state = state.copyWith(saving: true, clearError: true);
    final run = _queue.then((_) async {
      try {
        final AuthoredOutline base = _written ?? await ref.read(authoredOutlineProvider(projectId).future);
        _written = await putProposal(projectId, change(base.chapters));
        return true;
      } catch (e) {
        if (kDebugMode) debugPrint('[mara] proposal write failed: $e');
        _written = null;
        if (ref.mounted) state = state.copyWith(error: messageFor(e));
        return false;
      } finally {
        _pending--;
        if (_pending == 0) {
          _written = null;
          if (ref.mounted) {
            state = state.copyWith(saving: false);
            ref.invalidate(authoredOutlineProvider(projectId));
          }
        }
      }
    });
    _queue = run;
    return run;
  }

  /// Take a chapter out of the proposal, remembering where it was.
  Future<void> dropChapter(String id) async {
    final outline = ref.read(authoredOutlineProvider(projectId)).value;
    final found = outline == null ? null : locateChapter(outline.chapters, id);
    if (found == null) return;
    state = state.copyWith(dropped: [...state.dropped, found]);
    await edit((entries) => withoutChapter(entries, id));
  }

  Future<void> restoreDropped() async {
    final dropped = state.dropped;
    if (dropped.isEmpty) return;
    state = state.copyWith(dropped: const []);
    await edit((entries) => restoreChapters(entries, dropped));
  }

  /// Throw the proposal or changeset away. The plan stays.
  Future<void> dismiss() async {
    if (state.dismissing) return;
    state = state.copyWith(dismissing: true, clearError: true);
    try {
      await _queue;
      await dismissProposal(projectId);
      if (ref.mounted) state = state.copyWith(dismissing: false, dropped: const [], clearFilter: true);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(dismissing: false, error: messageFor(e));
    }
    _reread();
  }

  /// Make the proposal the book: a new draft (or the empty one's place), and
  /// the plan rows its chapters owe, through the plan's own owner.
  Future<void> commit({String? draftName}) async {
    if (state.committing) return;
    state = state.copyWith(committing: true, clearError: true);
    try {
      await _queue;
      final result = await commitProposal(projectId, draftName: draftName);
      ref.invalidate(projectProvider(projectId));
      ref.invalidate(projectWordCountProvider(projectId));
      try {
        // The board rebuilds against the new draft's tree first, so each
        // chapter's row is found rather than minted twice.
        await ref.read(planBoardProvider(projectId).future);
        ref.read(planBoardProvider(projectId).notifier).adoptCommitted([
          for (final c in result.chapters) (documentId: c.documentId, notes: c.notes, words: c.words),
        ]);
      } catch (e) {
        if (kDebugMode) debugPrint('[mara] commit plan rows failed: $e');
        if (ref.mounted) {
          state = state.copyWith(error: "The chapters were made, but their notes didn't reach the plan: ${messageFor(e)}");
        }
      }
      if (ref.mounted) {
        state = state.copyWith(
          committing: false,
          dropped: const [],
          clearFilter: true,
          committed: (
            count: result.chapters.length,
            draftName: result.draftName,
            firstFilename: result.chapters.firstOrNull?.filename,
          ),
        );
      }
    } catch (e) {
      if (ref.mounted) state = state.copyWith(committing: false, error: messageFor(e));
    }
    _reread();
  }

  void forgetCommit() => state = state.copyWith(clearCommitted: true);

  /// Project the approved ops into a proposal. [carry] is the author's answer
  /// to "start from the existing text", written over the server's default
  /// when they gave one.
  Future<void> applyChanges(List<ChangesetOp> approved, {bool? carry}) async {
    if (state.applying) return;
    state = state.copyWith(applying: true, clearError: true);
    try {
      final applied = await applyChangeset(projectId, approved);
      if (carry != null) await putProposal(projectId, withCarry(applied.chapters, carry));
      if (ref.mounted) state = state.copyWith(applying: false);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(applying: false, error: messageFor(e));
    }
    _reread();
  }

  void dismissError() => state = state.copyWith(clearError: true);

  void _reread() {
    if (ref.mounted) ref.invalidate(authoredOutlineProvider(projectId));
  }
}

final chapterPlanWritesProvider =
    NotifierProvider.autoDispose.family<ChapterPlanWrites, ChapterPlanState, String>(ChapterPlanWrites.new);
