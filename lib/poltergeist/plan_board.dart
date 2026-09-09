import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/projects.dart';
import '../server/errors.dart';
import '../server/projects/api.dart';
import '../server/providers.dart';
import 'ids.dart';
import 'plan_rules.dart';

/// Text edits coalesce into one save per pause; structural edits save at
/// once.
const Duration _notesDebounce = Duration(milliseconds: 700);

/// The stored plan didn't come back.
class PlanLoadFailed implements Exception {
  const PlanLoadFailed(this.cause);
  final Object cause;
}

/// The first open couldn't list the manuscript into a plan.
class PlanSeedFailed implements Exception {
  const PlanSeedFailed(this.cause);
  final Object cause;
}

/// The plan was written by another version of the app; this build won't
/// touch it.
class PlanFormatUnsupported implements Exception {
  const PlanFormatUnsupported(this.formatVersion);
  final int formatVersion;
}

class PlanBoardState {
  const PlanBoardState({required this.plan, this.saveError});
  final ProjectPlan plan;

  /// The last write didn't land — the board still shows the edit.
  final String? saveError;

  PlanBoardState copyWith({ProjectPlan? plan, String? saveError, bool clearError = false}) =>
      PlanBoardState(plan: plan ?? this.plan, saveError: clearError ? null : (saveError ?? this.saveError));
}

/// The board's state: the stored plan, seeded from the manuscript the first
/// time a project is opened with none, held against the chapter tree on
/// every open and every tree change, edited optimistically, and written back
/// whole — last-write-wins, like every blob surface.
///
/// The plan is re-read from the server on each build (tags can arrive from
/// the desktop), unless an edit is still unsaved here, in which case the
/// local copy is the truth and is reconciled in place. Writes coalesce: one
/// in flight, the latest plan queued behind it.
class PlanBoardNotifier extends AsyncNotifier<PlanBoardState> {
  PlanBoardNotifier(this.projectId);
  final String projectId;

  ProjectPlan? _unsaved;
  bool _saving = false;
  Timer? _notesTimer;
  ProjectPlan? _pendingNotes;

  @override
  Future<PlanBoardState> build() async {
    // Fires on a rebuild as well as on the room going away: either way a
    // typed edit rides the save queue rather than being left behind. The
    // queue itself outlives the notifier — `_drain` checks `ref.mounted`
    // before touching anything of ours.
    ref.onDispose(_flushNotes);

    final tree = (await ref.watch(projectProvider(projectId).future)).chapters;
    final now = nowIso();

    final ProjectPlan? stored;
    if (_unsaved != null) {
      stored = _unsaved;
    } else {
      try {
        stored = await ref.refresh(projectPlanProvider(projectId).future);
      } catch (e) {
        throw PlanLoadFailed(e);
      }
    }

    if (stored == null) {
      // No stored plan — the board seeds itself rather than asking, so the
      // first open lands on the chapter list.
      final seeded = seedPlan(tree, now: now, newId: newId);
      try {
        await putProjectPlan(projectId, seeded);
      } catch (e) {
        throw PlanSeedFailed(e);
      }
      ref.invalidate(projectPlanProvider(projectId));
      return PlanBoardState(plan: seeded);
    }
    if (stored.formatVersion != planFormatVersion) throw PlanFormatUnsupported(stored.formatVersion);

    final result = reconcilePlan(stored, tree, now: now, newId: newId);
    if (result.changed) _save(result.plan);
    return PlanBoardState(plan: result.plan);
  }

  List<ChaptersListEntry> get _tree => ref.read(projectProvider(projectId)).value?.chapters ?? const [];

  void _show(ProjectPlan plan, {bool clearError = false}) {
    final base = state.value;
    state = AsyncData(base == null ? PlanBoardState(plan: plan) : base.copyWith(plan: plan, clearError: clearError));
  }

  /// Queue a write of `plan`. One PUT in flight at a time; a plan queued while
  /// one runs replaces any earlier queued plan, so the server always ends on
  /// the latest.
  void _save(ProjectPlan plan) {
    _unsaved = plan;
    if (_saving) return;
    _saving = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    try {
      while (_unsaved != null) {
        final plan = _unsaved!;
        try {
          await putProjectPlan(projectId, plan);
          if (identical(_unsaved, plan)) _unsaved = null;
          // The chapter list's dots read the stored plan.
          if (ref.mounted) ref.invalidate(projectPlanProvider(projectId));
        } catch (e) {
          if (kDebugMode) debugPrint('[plan] save failed: $e');
          if (identical(_unsaved, plan)) _unsaved = null;
          if (!ref.mounted) return;
          final base = state.value;
          if (base != null) state = AsyncData(base.copyWith(saveError: messageFor(e)));
        }
      }
    } finally {
      _saving = false;
    }
  }

  void _commit(ProjectPlan next) {
    _show(next, clearError: true);
    _save(next);
  }

  /// One action-state change on a row: assign, clear, confirm, done, undone.
  void act(String rowId, PlanOp op, {PlanActionKind? kind}) {
    final current = state.value?.plan;
    if (current == null) return;
    _flushNotes();
    final next = applyPlanOp(current, rowId, op, kind: kind, tree: _tree, now: nowIso());
    if (next != null) _commit(next);
  }

  /// Notes ride a debounce; everything else flushes them first so the writes
  /// stay ordered.
  void setNotes(String rowId, String notes) {
    final current = state.value?.plan;
    if (current == null) return;
    final next = withRowNotes(current, rowId, notes);
    _show(next);
    _pendingNotes = next;
    _notesTimer?.cancel();
    _notesTimer = Timer(_notesDebounce, _flushNotes);
  }

  void _flushNotes() {
    _notesTimer?.cancel();
    _notesTimer = null;
    final pending = _pendingNotes;
    if (pending == null) return;
    _pendingNotes = null;
    _save(pending);
  }

  /// Only missing rows can leave the board by hand.
  void removeRow(String rowId) {
    final current = state.value?.plan;
    if (current == null) return;
    _flushNotes();
    final next = withoutRow(current, rowId);
    if (next != null) _commit(next);
  }

  /// Try the last failed write again with what the board shows now.
  void retrySave() {
    final current = state.value?.plan;
    if (current == null) return;
    _commit(current);
  }
}
