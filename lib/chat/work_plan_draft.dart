import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../autosave/field_autosave.dart';
import '../server/chat/api.dart';
import '../server/dto/work_plan.dart';
import '../server/errors.dart';
import 'providers.dart';

/// A work plan's text as a field that saves itself, conditionally: every
/// save names the version it was typed against, because the chat keeps the
/// same plan current from the server side. When the chat got there first
/// (409 `version_conflict`) the field takes the chat's copy and says so —
/// the plan is the chat's working notes, and a stale copy saved over them
/// would undo a turn the author just read.
class WorkPlanDraft {
  WorkPlanDraft(this._container, this.projectId, WorkPlan plan)
      : planId = plan.id,
        _version = plan.version {
    autosave = FieldAutosave(initial: plan.text, save: _save);
  }

  final ProviderContainer _container;
  final String projectId;
  final String planId;
  int _version;
  bool _disposed = false;
  late final FieldAutosave autosave;

  /// True once the field has taken the chat's copy over the author's.
  final ValueNotifier<bool> replaced = ValueNotifier(false);

  Future<void> _save(String text) async {
    try {
      _version = (await patchWorkPlan(projectId, planId, text: text, baseVersion: _version)).version;
      _container.invalidate(workPlansProvider(projectId));
    } on ServerError catch (e) {
      if (e.code != 'version_conflict') rethrow;
      final current = await getWorkPlan(projectId, planId);
      _version = current.version;
      // FieldAutosave records a returned save as landed; the reset must come
      // after it has, or it would take the author's text as what the server
      // holds.
      Timer.run(() => _take(current, announce: true));
    }
  }

  /// Read the plan again after a turn that may have written it, and take the
  /// server's copy when nothing typed is waiting to go.
  Future<void> refresh() async {
    if (autosave.status != FieldSaveStatus.saved) return;
    try {
      final current = await getWorkPlan(projectId, planId);
      if (autosave.status == FieldSaveStatus.saved) _take(current, announce: false);
    } catch (e) {
      if (kDebugMode) debugPrint('[WorkPlanDraft] refresh failed: $e');
    }
  }

  void _take(WorkPlan current, {required bool announce}) {
    if (_disposed) return;
    _version = current.version;
    if (autosave.text.text != current.text) autosave.reset(current.text);
    if (announce) replaced.value = true;
  }

  void dispose() {
    _disposed = true;
    replaced.dispose();
    autosave.dispose();
  }
}
