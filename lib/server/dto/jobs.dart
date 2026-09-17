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

/// A choice a question offers. With `inputPlaceholder`, picking it opens a
/// free-text field first and the text rides the answer.
class JobQuestionOption {
  const JobQuestionOption({required this.id, required this.label, this.inputPlaceholder});
  final String id;
  final String label;
  final String? inputPlaceholder;

  static JobQuestionOption fromJson(Json json) => JobQuestionOption(
        id: asString(json['id']),
        label: asString(json['label']),
        inputPlaceholder: json['input'] is Map ? asString(asJson(json['input'])['placeholder']) : null,
      );
}

/// A non-blocking question a run asks the author — continuity's "which is
/// the story?". Ids are stable across runs and rehydrations.
class JobQuestion {
  const JobQuestion({required this.id, required this.question, required this.detail, required this.options});
  final String id;
  final String question;
  final String? detail;
  final List<JobQuestionOption> options;

  static JobQuestion fromJson(Json json) => JobQuestion(
        id: asString(json['id']),
        question: asString(json['question']),
        detail: json['detail'] as String?,
        options: asJsonList(json['options']).map(JobQuestionOption.fromJson).toList(),
      );
}

/// One job's state. `errorDetail` is the author-facing explanation — render it
/// rather than branching on `error`, which is a wire code.
///
/// `subject` is what the run is about in the kind's own vocabulary (an
/// `edit_pass` names a chapter's document id or `outline`); `result` is what
/// a finished run left on its row when the kind keeps its answer there (the
/// pass's notes, an `EditPassResult`). Both null for every other kind.
class JobSnapshot {
  const JobSnapshot({
    required this.id,
    required this.kind,
    required this.projectId,
    required this.label,
    required this.status,
    required this.progress,
    this.questions = const [],
    required this.error,
    required this.errorDetail,
    required this.summary,
    required this.subject,
    required this.result,
  });

  final String id;
  final String kind;
  final String projectId;
  final String label;
  final JobStatus status;
  final JobProgress? progress;
  final List<JobQuestion> questions;
  final String? error;
  final String? errorDetail;
  final String? summary;
  final String? subject;
  final Object? result;

  bool get isRunning => status == JobStatus.running;

  static JobSnapshot fromJson(Json json) => JobSnapshot(
        id: asString(json['id']),
        kind: asString(json['kind']),
        projectId: asString(json['project_id']),
        label: asString(json['label']),
        status: JobStatus.fromWire(json['status'] as String?),
        progress: json['progress'] == null ? null : JobProgress.fromJson(asJson(json['progress'])),
        questions: asJsonList(json['questions']).map(JobQuestion.fromJson).toList(),
        error: json['error'] as String?,
        errorDetail: json['error_detail'] as String?,
        summary: json['summary'] as String?,
        subject: json['subject'] as String?,
        result: json['result'],
      );
}
