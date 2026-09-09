import '../client.dart';
import '../dto/jobs.dart';
import '../dto/json.dart';

/// GET /api/projects/{id}/jobs/{jobId} — one job's current state. Mobile
/// follows a job by asking, where the desktop is told over `/ws`.
Future<JobSnapshot> getJob(String projectId, String jobId) async {
  final res = await apiFetch('/api/projects/$projectId/jobs/$jobId');
  return JobSnapshot.fromJson(asJson(res.jsonObject()['job']));
}

/// POST /api/projects/{id}/jobs — start a pipeline and get its first
/// snapshot. 409 `job_running` when a job of the same kind is already going.
Future<JobSnapshot> startJob(String projectId, String kind, {Map<String, dynamic> params = const {}}) async {
  final res = await apiFetch('/api/projects/$projectId/jobs', method: 'POST', body: {'kind': kind, ...params});
  return JobSnapshot.fromJson(asJson(res.jsonObject()['job']));
}

/// GET /api/projects/{id}/jobs — running rows plus retained finished ones,
/// newest first.
Future<List<JobSnapshot>> listJobs(String projectId) async {
  final res = await apiFetch('/api/projects/$projectId/jobs');
  return asJsonList(res.jsonObject()['jobs']).map(JobSnapshot.fromJson).toList();
}
