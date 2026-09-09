import '../client.dart';
import '../dto/json.dart';
import '../dto/poltergeist.dart';

// Poltergeist's routes: the words series and the task list. The plan's
// GET/PUT live in projects/api.dart beside the project they belong to.

/// The daily words series, oldest first, one entry per local day with quiet
/// days filled in. The offset is this phone's: a writing day ends at the
/// author's midnight, not the server's.
Future<List<WordStatsDay>> getProjectWordStats(String projectId, {int days = 30, int? tzOffsetMinutes}) async {
  final offset = tzOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
  final res = await apiFetch('/api/projects/$projectId/word-stats?days=$days&tz_offset=$offset');
  return asJsonList(res.jsonObject()['days']).map(WordStatsDay.fromJson).toList();
}

/// The stored list, or null when the writer has never added a task.
Future<ProjectTasks?> getProjectTasks(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/tasks');
  final tasks = res.jsonObject()['tasks'];
  return tasks == null ? null : ProjectTasks.fromJson(asJson(tasks));
}

/// Prepends one task (newest first). Ids are client-minted, so a replayed add
/// replaces rather than duplicates.
Future<ProjectTasks> addProjectTask(String projectId, TaskItem task) async {
  final res = await apiFetch('/api/projects/$projectId/tasks', method: 'POST', body: {
    'format_version': tasksFormatVersion,
    'task': task.toJson(),
  });
  return ProjectTasks.fromJson(asJson(res.jsonObject()['tasks']));
}

/// Replaces one task in place. A task that no longer exists is 404
/// `task_not_found`.
Future<ProjectTasks> updateProjectTask(String projectId, TaskItem task) async {
  final res = await apiFetch('/api/projects/$projectId/tasks/${task.id}', method: 'PATCH', body: {'task': task.toJson()});
  return ProjectTasks.fromJson(asJson(res.jsonObject()['tasks']));
}

/// Idempotent: a task already gone is still 200. Null when the list never
/// existed.
Future<ProjectTasks?> deleteProjectTask(String projectId, String taskId) async {
  final res = await apiFetch('/api/projects/$projectId/tasks/$taskId', method: 'DELETE');
  final tasks = res.jsonObject()['tasks'];
  return tasks == null ? null : ProjectTasks.fromJson(asJson(tasks));
}
