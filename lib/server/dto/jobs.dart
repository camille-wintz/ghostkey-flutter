import 'json.dart';

enum JobStatus {
  running,
  done,
  error,
  cancelled;

  static JobStatus fromWire(String? value) => switch (value) {
        'done' => JobStatus.done,
        'error' => JobStatus.error,
        'cancelled' => JobStatus.cancelled,
        _ => JobStatus.running,
      };
}

/// Overall progress. The pipeline computes the pass-weighted `fraction` — a
/// client just draws one honest bar.
class JobProgress {
  const JobProgress({
    required this.label,
    required this.current,
    required this.total,
    required this.fraction,
    required this.indeterminate,
  });

  final String label;
  final int current;
  final int total;
  final double fraction;
  final bool indeterminate;

  static JobProgress fromJson(Json json) => JobProgress(
        label: asString(json['label']),
        current: asInt(json['current']),
        total: asInt(json['total']),
        fraction: asDouble(json['fraction']),
        indeterminate: asBool(json['indeterminate']),
      );
}

/// One job's state. `errorDetail` is the author-facing explanation — render it
/// rather than branching on `error`, which is a wire code.
class JobSnapshot {
  const JobSnapshot({
    required this.id,
    required this.kind,
    required this.projectId,
    required this.label,
    required this.status,
    required this.progress,
    required this.error,
    required this.errorDetail,
    required this.summary,
  });

  final String id;
  final String kind;
  final String projectId;
  final String label;
  final JobStatus status;
  final JobProgress? progress;
  final String? error;
  final String? errorDetail;
  final String? summary;

  bool get isRunning => status == JobStatus.running;

  static JobSnapshot fromJson(Json json) => JobSnapshot(
        id: asString(json['id']),
        kind: asString(json['kind']),
        projectId: asString(json['project_id']),
        label: asString(json['label']),
        status: JobStatus.fromWire(json['status'] as String?),
        progress: json['progress'] == null ? null : JobProgress.fromJson(asJson(json['progress'])),
        error: json['error'] as String?,
        errorDetail: json['error_detail'] as String?,
        summary: json['summary'] as String?,
      );
}
