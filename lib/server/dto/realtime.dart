import 'jobs.dart';
import 'json.dart';

// The `/ws` fanout's one event shape, ProjectChangeEvent: which project,
// which entity, which row. The entity-specific fields stay in [raw] for the
// reader that knows the entity (chat_conversation.dart reads the chat ones).

class ProjectChangeEvent {
  const ProjectChangeEvent({
    required this.projectId,
    required this.entity,
    required this.kind,
    required this.id,
    required this.raw,
  });

  final String projectId;

  /// project, document, job, chat_session, chat_message, chat_stream, … —
  /// kept as the wire string so a new entity is simply one nobody reads.
  final String entity;

  /// insert | update | delete, or `stream` on a chat_stream frame.
  final String kind;
  final String id;
  final Json raw;

  /// On `entity: "job"`: the job's status, when the event carried the job.
  JobStatus? get jobStatus => switch (raw['job']) {
        {'status': final String status} => JobStatus.fromWire(status),
        _ => null,
      };

  /// Null for any frame that is not a project change (ping, subscribe acks).
  static ProjectChangeEvent? fromJson(Object? json) {
    if (json is! Map || json['type'] != 'project_changes') return null;
    final map = json.cast<String, dynamic>();
    return ProjectChangeEvent(
      projectId: asString(map['project_id']),
      entity: asString(map['entity']),
      kind: asString(map['kind']),
      id: asString(map['id']),
      raw: map,
    );
  }
}
