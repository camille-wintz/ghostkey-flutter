import 'json.dart';

// Work plans — a named markdown document per task the author brings to the
// chat. Hand-written against the contract's WorkPlan / WorkPlanSummary.

class WorkPlan {
  const WorkPlan({
    required this.id,
    required this.projectId,
    required this.name,
    required this.text,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String projectId;
  final String name;

  /// Markdown: Goal, Decided, Open, Next to start with, then the author's.
  final String text;

  /// Bumps on every text save; a rename alone leaves it.
  final int version;
  final String createdAt;
  final String updatedAt;

  static WorkPlan fromJson(Json json) => WorkPlan(
        id: asString(json['id']),
        projectId: asString(json['project_id']),
        name: asString(json['name']),
        text: asString(json['text']),
        version: asInt(json['version']),
        createdAt: asString(json['created_at']),
        updatedAt: asString(json['updated_at']),
      );
}

/// One conversation under a plan, as the plans listing names it.
class WorkPlanSessionRef {
  const WorkPlanSessionRef({required this.id, required this.title, required this.updatedAt});
  final String id;
  final String title;
  final String updatedAt;

  static WorkPlanSessionRef fromJson(Json json) => WorkPlanSessionRef(
        id: asString(json['id']),
        title: asString(json['title']),
        updatedAt: asString(json['updated_at']),
      );
}

/// A plan in the listing: its name, the line under its Goal, and the
/// conversations that work under it, newest first.
class WorkPlanSummary {
  const WorkPlanSummary({
    required this.id,
    required this.name,
    required this.goal,
    required this.version,
    required this.updatedAt,
    this.sessions = const [],
  });
  final String id;
  final String name;
  final String goal;
  final int version;
  final String updatedAt;
  final List<WorkPlanSessionRef> sessions;

  static WorkPlanSummary fromJson(Json json) => WorkPlanSummary(
        id: asString(json['id']),
        name: asString(json['name']),
        goal: asString(json['goal']),
        version: asInt(json['version']),
        updatedAt: asString(json['updated_at']),
        sessions: asJsonList(json['sessions']).map(WorkPlanSessionRef.fromJson).toList(),
      );
}
