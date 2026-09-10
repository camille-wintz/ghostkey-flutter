import '../client.dart';
import '../dto/profile.dart';

// GET / PUT /api/me/profile — the author's own answers from the first-run flow.
//
// The PUT is partial per key: only what is passed is written, so each question
// saves as it is answered and an abandoned flow still leaves what it learned.
// `completed` and `skipped` are booleans on the wire, not timestamps — when the
// flow finished is the server's to know.

Future<AuthorProfile> getAuthorProfile() async {
  final res = await apiFetch('/api/me/profile');
  return AuthorProfile.fromJson(res.jsonObject());
}

Future<AuthorProfile> saveAuthorProfile({
  Experience? experience,
  StartMode? startMode,
  Intent? intent,
  String? firstProjectId,
  bool? completed,
  bool? skipped,
}) async {
  final res = await apiFetch('/api/me/profile', method: 'PUT', body: {
    if (experience != null) 'experience': experience.wire,
    if (startMode != null) 'start_mode': startMode.wire,
    if (intent != null) 'intent': intent.wire,
    'first_project_id': ?firstProjectId,
    'completed': ?completed,
    'skipped': ?skipped,
  });
  return AuthorProfile.fromJson(res.jsonObject());
}
