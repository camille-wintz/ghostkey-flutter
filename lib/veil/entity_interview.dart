import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/bible.dart';
import '../server/errors.dart';
import 'entity_writes.dart';

/// One sitting of the dossier interview on a card: a question at a time,
/// each answer filed into the dossier verbatim by the server before the next
/// is asked. The server is stateless, so the sitting's asked labels live
/// here; a new sitting is a new instance. The desk's `useEntityInterview`.
class EntityInterview extends ChangeNotifier {
  EntityInterview(this._ref, this.projectId, this.entityId);

  final WidgetRef _ref;
  final String projectId;
  final String entityId;

  InterviewQuestion? question;
  final List<String> _asked = [];
  bool busy = false;
  String? error;
  bool _disposed = false;

  /// The first question of the sitting.
  Future<bool> start() => _step('', next: true);

  /// File [answer] (a blank one is a skip) and ask the next question.
  Future<bool> next(String answer) => _step(answer, next: true);

  /// File [answer], if any, and stop. False when filing it failed.
  Future<bool> finish(String answer) async =>
      answer.trim().isEmpty || question == null || await _step(answer, next: false);

  Future<bool> _step(String answer, {required bool next}) async {
    final answering = question;
    final labels = [..._asked, ?answering?.label];
    busy = true;
    error = null;
    _notify();
    try {
      final asked = await interviewStep(
        _ref,
        projectId,
        entityId,
        answering: answering,
        answer: answer,
        asked: labels,
        next: next,
      );
      _asked
        ..clear()
        ..addAll(labels);
      question = asked;
      return true;
    } catch (e) {
      error = _describe(e);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String _describe(Object e) => switch (e) {
      ServerError(code: 'dossier_full') => 'The dossier is full — trim it before adding more.',
      ServerError(code: 'rate_limited') => 'Too many at once. Give it a minute.',
      ServerError(code: 'network_error') => "You're offline.",
      ServerError(code: 'plan_insufficient') => messageFor(e),
      _ => 'No question came back. Try again.',
    };
