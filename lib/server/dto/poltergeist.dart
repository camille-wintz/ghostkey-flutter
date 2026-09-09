import 'json.dart';

// Poltergeist's own wire shapes: the daily words series and the manual task
// list. The plan lives in projects.dart because the chapter list reads it too.

/// One local calendar day of `GET /api/projects/{id}/word-stats`. `written`
/// is words put down — added and rewritten count, deletions don't, so it
/// never goes down. `total` is manuscript size, which can fall.
class WordStatsDay {
  const WordStatsDay({required this.day, required this.total, required this.written});

  /// `YYYY-MM-DD`, already the author's local day per the request's offset.
  final String day;
  final int total;
  final int written;

  static WordStatsDay fromJson(Json json) => WordStatsDay(
        day: asString(json['day']),
        total: asInt(json['total']),
        written: asInt(json['written']),
      );
}

/// The tasks format this build writes; sent only when the first-ever task
/// creates the list.
const int tasksFormatVersion = 1;

/// One manual task. Client-owned JSON: the server validates id/title and
/// passes the rest through, so `raw` is echoed on every write.
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.completedAt,
    required this.raw,
  });

  final String id;
  final String title;
  final String createdAt;

  /// Null while the task is open.
  final String? completedAt;
  final Json raw;

  bool get isOpen => completedAt == null;

  factory TaskItem.create({required String id, required String title, required String now}) => TaskItem.fromJson({
        'id': id,
        'title': title,
        'created_at': now,
        'completed_at': null,
      });

  static TaskItem fromJson(Json json) => TaskItem(
        id: asString(json['id']),
        title: asString(json['title']),
        createdAt: asString(json['created_at']),
        completedAt: json['completed_at'] as String?,
        raw: json,
      );

  TaskItem withCompletedAt(String? completedAt) {
    final next = Map<String, dynamic>.from(raw);
    next['completed_at'] = completedAt;
    return TaskItem.fromJson(next);
  }

  Json toJson() => raw;
}

/// The list, read whole; mutated one task at a time.
class ProjectTasks {
  const ProjectTasks({required this.formatVersion, required this.tasks, required this.raw});
  final int formatVersion;

  /// Array order is the list order; open-before-done is a display concern.
  final List<TaskItem> tasks;
  final Json raw;

  /// The list before the first task exists.
  factory ProjectTasks.empty() => ProjectTasks.fromJson({
        'format_version': tasksFormatVersion,
        'tasks': const <Json>[],
      });

  static ProjectTasks fromJson(Json json) => ProjectTasks(
        formatVersion: asInt(json['format_version']),
        tasks: asJsonList(json['tasks']).map(TaskItem.fromJson).toList(),
        raw: json,
      );

  ProjectTasks withTasks(List<TaskItem> next) {
    final json = Map<String, dynamic>.from(raw);
    json['tasks'] = next.map((t) => t.toJson()).toList();
    return ProjectTasks.fromJson(json);
  }

  Json toJson() => raw;
}
