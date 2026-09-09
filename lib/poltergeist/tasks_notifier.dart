import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/poltergeist.dart';
import '../server/errors.dart';
import '../server/poltergeist/api.dart';
import 'ids.dart';

/// The list as the room holds it, and whether an edit is still owed to the
/// server.
class TasksState {
  const TasksState({required this.tasks, this.saveFailed = false});

  /// Null until the first task — the server has no list yet.
  final ProjectTasks? tasks;

  /// An op never landed and waits for a replay; the edit is already on
  /// screen.
  final bool saveFailed;

  TasksState copyWith({ProjectTasks? tasks, bool clearTasks = false, bool? saveFailed}) => TasksState(
        tasks: clearTasks ? null : (tasks ?? this.tasks),
        saveFailed: saveFailed ?? this.saveFailed,
      );
}

/// Open tasks in list order — the dashboard shows the first three.
List<TaskItem> openTasks(ProjectTasks? tasks) => (tasks?.tasks ?? const []).where((t) => t.isOpen).toList();

/// Completed tasks, most recently finished first.
List<TaskItem> doneTasks(ProjectTasks? tasks) => (tasks?.tasks ?? const []).where((t) => !t.isOpen).toList()
  ..sort((a, b) => (b.completedAt ?? '').compareTo(a.completedAt ?? ''));

/// The manual task list: read whole, edited optimistically, and saved ONE
/// TASK PER CALL. Every edit saves immediately — task edits are discrete
/// taps, not typing. Failed ops queue for a one-tap replay.
class TasksNotifier extends AsyncNotifier<TasksState> {
  TasksNotifier(this.projectId);
  final String projectId;

  final List<Future<ProjectTasks?> Function()> _failed = [];

  @override
  Future<TasksState> build() async => TasksState(tasks: await getProjectTasks(projectId));

  ProjectTasks get _current => state.value?.tasks ?? ProjectTasks.empty();

  void _show(ProjectTasks? tasks, {bool? saveFailed}) {
    if (!ref.mounted) return;
    final base = state.value ?? const TasksState(tasks: null);
    state = AsyncData(TasksState(tasks: tasks, saveFailed: saveFailed ?? base.saveFailed));
  }

  /// Runs one op; the server's list replaces ours when it lands. A target
  /// that no longer exists means a replay can never land, so re-sync instead
  /// of queueing.
  Future<void> _send(Future<ProjectTasks?> Function() op) async {
    try {
      final settled = await op();
      // A delete on a list that never existed answers null — nothing changed.
      if (settled != null) _show(settled);
    } on ServerError catch (e) {
      if (e.code == 'task_not_found' || e.status == 404) {
        if (ref.mounted) ref.invalidateSelf();
        return;
      }
      if (kDebugMode) debugPrint('[tasks] save failed: $e');
      _failed.add(op);
      _show(_current, saveFailed: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[tasks] save failed: $e');
      _failed.add(op);
      _show(_current, saveFailed: true);
    }
  }

  /// Newest first — a fresh task lands at the top of the list.
  void add(String title) {
    // Never edit before the first load lands: an op built on the empty
    // default could target a list the server hasn't shown us yet.
    if (!state.hasValue) return;
    final task = TaskItem.create(id: newId(), title: title, now: nowIso());
    _show(_current.withTasks([task, ..._current.tasks]));
    unawaited(_send(() => addProjectTask(projectId, task)));
  }

  void toggle(String id) {
    if (!state.hasValue) return;
    TaskItem? toggled;
    final next = [
      for (final task in _current.tasks)
        if (task.id == id) toggled = task.withCompletedAt(task.isOpen ? nowIso() : null) else task,
    ];
    final target = toggled;
    if (target == null) return;
    _show(_current.withTasks(next));
    unawaited(_send(() => updateProjectTask(projectId, target)));
  }

  void remove(String id) {
    if (!state.hasValue) return;
    _show(_current.withTasks(_current.tasks.where((t) => t.id != id).toList()));
    unawaited(_send(() => deleteProjectTask(projectId, id)));
  }

  /// Replay every op that never landed — the edits are already on screen. A
  /// replay that fails again just re-queues.
  void retry() {
    final queue = List.of(_failed);
    _failed.clear();
    _show(_current, saveFailed: false);
    for (final op in queue) {
      unawaited(_send(op));
    }
  }
}
