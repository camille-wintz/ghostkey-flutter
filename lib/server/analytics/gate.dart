import '../client.dart';

/// Which of the two walls an author was shown: `plan` is "your tier may not",
/// `quota` is "you have none left". The server's vocabulary (POST
/// /api/analytics/gate).
enum GateKind { plan, quota }

/// Tell the server an author was shown a wall — once per notice, and only for
/// one the server never saw: a send the cached snapshot stopped, or a locked
/// row picked. A refusal the server made and counted carries
/// `ServerError.wallRecorded`, and its notice reports nothing. `id` is a
/// capability id for [GateKind.plan], a quota feature id for [GateKind.quota];
/// the server derives the plan itself. Never awaited and never throws: the
/// caller is a notice opening, and `apiFetch` already logs a failure.
void reportGateShown(GateKind gate, String id) {
  apiFetch('/api/analytics/gate', method: 'POST', body: {'gate': gate.name, 'id': id}).ignore();
}
