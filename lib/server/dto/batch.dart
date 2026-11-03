import 'chat.dart';
import 'json.dart';

// A batch (`GET /projects/{id}/batches/{batchId}`): a frozen list of items worked
// through on the server, whose state outlives any one run. Hand-written against
// the contract's Batch / BatchCounts / BatchItem. A status this build doesn't
// know reads as `unknown` rather than throwing.

enum BatchStatus {
  waiting,
  running,
  paused,
  reviewing,
  done,
  unknown;

  static BatchStatus fromWire(Object? value) => values.where((s) => s.name == value).firstOrNull ?? unknown;
}

class BatchOpenNote {
  const BatchOpenNote({required this.quote, required this.note});
  final String quote;
  final String note;

  static BatchOpenNote fromJson(Json json) => BatchOpenNote(quote: asString(json['quote']), note: asString(json['note']));
}

class BatchItem {
  const BatchItem({
    required this.seq,
    required this.subject,
    required this.label,
    required this.status,
    this.summary,
    this.opens,
    this.open = const [],
    this.canUndo = false,
    this.undone = false,
    this.error,
  });

  final int seq;

  /// The chapter's document id.
  final String subject;
  final String label;

  /// pending | running | done | skipped | failed.
  final String status;
  final String? summary;

  /// The document its row opens, when it isn't the subject.
  final String? opens;
  final List<BatchOpenNote> open;
  final bool canUndo;
  final bool undone;
  final String? error;

  bool get waiting => status == 'pending' || status == 'running';

  static BatchItem fromJson(Json json) {
    final outcome = json['outcome'] is Map ? asJson(json['outcome']) : const <String, dynamic>{};
    final undone = outcome['undone'] == true;
    return BatchItem(
      seq: asInt(json['seq']),
      subject: asString(json['subject']),
      label: asString(json['label']),
      status: asString(json['status']),
      summary: nonEmptyString(outcome['summary']),
      opens: nonEmptyString(outcome['opens']),
      open: asJsonList(outcome['open']).map(BatchOpenNote.fromJson).toList(),
      canUndo: outcome['undo'] is Map && !undone,
      undone: undone,
      error: nonEmptyString(json['error']),
    );
  }
}

class BatchPage {
  const BatchPage({
    required this.id,
    required this.label,
    required this.status,
    required this.applies,
    required this.pauseReason,
    required this.jobId,
    required this.total,
    required this.finished,
    required this.failed,
    required this.items,
    required this.next,
    this.runningLine,
    this.doneLine,
  });

  final String id;
  final String label;
  final BatchStatus status;

  /// Writes into the text, or leaves notes. Null while it waits on the author.
  final bool? applies;
  final String? pauseReason;

  /// The run narrating it now.
  final String? jobId;
  final int total;

  /// Done, skipped or failed.
  final int finished;
  final int failed;
  final List<BatchItem> items;

  /// Past the last item of this page, when there are more.
  final int? next;

  /// What the page says, when the work has its own words for it.
  final String? runningLine;
  final String? doneLine;

  bool get live => status == BatchStatus.running || status == BatchStatus.reviewing;

  BatchPage withItems(List<BatchItem> all) => BatchPage(
        id: id,
        label: label,
        status: status,
        applies: applies,
        pauseReason: pauseReason,
        jobId: jobId,
        total: total,
        finished: finished,
        failed: failed,
        items: all,
        next: null,
        runningLine: runningLine,
        doneLine: doneLine,
      );

  static BatchPage fromJson(Json json) {
    final batch = asJson(json['batch']);
    final counts = asJson(json['counts']);
    final failed = asInt(counts['failed']);
    return BatchPage(
      id: asString(batch['id']),
      label: asString(batch['label']),
      status: BatchStatus.fromWire(batch['status']),
      applies: batch['applies'] is bool ? batch['applies'] as bool : null,
      pauseReason: nonEmptyString(batch['pause_reason']),
      jobId: nonEmptyString(batch['job_id']),
      total: asInt(counts['total']),
      finished: asInt(counts['done']) + asInt(counts['skipped']) + failed,
      failed: failed,
      items: asJsonList(json['items']).map(BatchItem.fromJson).toList(),
      next: json['next'] is num ? (json['next'] as num).toInt() : null,
      runningLine: nonEmptyString(batch['running_line']),
      doneLine: nonEmptyString(batch['done_line']),
    );
  }
}
