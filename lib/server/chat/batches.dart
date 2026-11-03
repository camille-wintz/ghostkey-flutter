import '../client.dart';
import '../dto/batch.dart';
import '../jobs/api.dart';

// A batch's routes. Its stop is its job's (`dismissJob`).

String _base(String projectId, String batchId) => '/api/projects/$projectId/batches/$batchId';

/// The batch and every item: the page lists the whole of it.
Future<BatchPage> readBatch(String projectId, String batchId) async {
  final first = BatchPage.fromJson((await apiFetch(_base(projectId, batchId))).jsonObject());
  final items = [...first.items];
  var next = first.next;
  while (next != null) {
    final page = BatchPage.fromJson((await apiFetch('${_base(projectId, batchId)}?after=$next')).jsonObject());
    items.addAll(page.items);
    next = page.next;
  }
  return first.withItems(items);
}

/// The author's answer to a batch waiting on one, kept as the account's choice.
Future<void> startBatch(String projectId, String batchId, {required bool apply}) async {
  await apiFetch('${_base(projectId, batchId)}/start', method: 'POST', body: {'apply': apply});
}

Future<void> resumeBatch(String projectId, String batchId) async {
  await apiFetch('${_base(projectId, batchId)}/resume', method: 'POST');
}

/// Close a batch still waiting on the author's answer.
Future<void> cancelWaitingBatch(String projectId, String batchId) async {
  await apiFetch(_base(projectId, batchId), method: 'DELETE');
}

Future<void> undoBatchItem(String projectId, String batchId, int seq) async {
  await apiFetch('${_base(projectId, batchId)}/items/$seq/undo', method: 'POST');
}

Future<void> stopBatch(String projectId, String jobId) => dismissJob(projectId, jobId);

/// Whether the chat's line edits write straight in. Null until answered.
Future<bool?> readAutoLineEdit() async {
  final prefs = (await apiFetch('/api/me/preferences')).jsonObject();
  return prefs['auto_line_edit'] is bool ? prefs['auto_line_edit'] as bool : null;
}

Future<void> setAutoLineEdit(bool on) async {
  await apiFetch('/api/me/preferences', method: 'PATCH', body: {'auto_line_edit': on});
}
