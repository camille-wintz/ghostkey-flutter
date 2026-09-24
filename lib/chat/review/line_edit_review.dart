import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locate_quote.dart';
import '../../core/typography.dart';
import '../../server/dto/edit_pass.dart';
import '../../server/errors.dart';
import '../../server/jobs/api.dart';
import '../../server/plan/api.dart';
import '../../server/projects/api.dart';
import '../../server/providers.dart';
import '../../mara/providers.dart';
import 'providers.dart';

// One finished edit pass, reviewed a note at a time: the phone's EditReview.
// The text is read once, on open, and from then on this owner holds it —
// every accept is a write of the whole text with the passage replaced, and
// what comes back is the new copy the next note resolves against.
//
// Verdicts are local, as on the desk: nothing about an accepted or rejected
// note is recorded on the job row. Done deletes the row, and the notes with it
// — and the last verdict is Done on its own, after a beat, as on the desk
// (2026-09-23): with every note ruled on there is nothing left to press for.

/// How long a fully answered pass stays up before it closes itself.
const _autoDoneDelay = Duration(milliseconds: 900);

enum NoteVerdict { pending, accepted, rejected }

class ReviewedNote {
  const ReviewedNote(this.note, [this.verdict = NoteVerdict.pending]);
  final EditNote note;
  final NoteVerdict verdict;
}

/// The subject's text and its version — null for the outline, whose route
/// takes none.
typedef SubjectText = ({String text, int? version});

class LineEditState {
  const LineEditState({
    required this.jobId,
    required this.result,
    required this.text,
    required this.version,
    required this.notes,
    this.index = 0,
    this.saving = false,
    this.error,
  });

  final String jobId;
  final EditPassResult result;
  final String text;
  final int? version;
  final List<ReviewedNote> notes;

  /// The note on show.
  final int index;
  final bool saving;
  final String? error;

  ReviewedNote get current => notes[index];
  int get pendingCount => notes.where((n) => n.verdict == NoteVerdict.pending).length;
  int get acceptedCount => notes.where((n) => n.verdict == NoteVerdict.accepted).length;

  /// The current note against the text as it stands now.
  ResolvedNote get resolved => resolveNote(text, current.note.quote, current.note.suggestion);

  /// Where the current note's passage is, to highlight — located whether or
  /// not it carries a fix.
  QuoteRange? get currentRange => findUniqueQuoteRange(text, current.note.quote);

  LineEditState copyWith({
    String? text,
    int? version,
    List<ReviewedNote>? notes,
    int? index,
    bool? saving,
    String? error,
    bool clearError = false,
  }) =>
      LineEditState(
        jobId: jobId,
        result: result,
        text: text ?? this.text,
        version: version ?? this.version,
        notes: notes ?? this.notes,
        index: index ?? this.index,
        saving: saving ?? this.saving,
        error: clearError ? null : (error ?? this.error),
      );
}

typedef LineEditKey = ({String projectId, String subject, String jobId});

final lineEditReviewProvider = AsyncNotifierProvider.autoDispose.family<LineEditReview, LineEditState, LineEditKey>(
  LineEditReview.new,
);

class LineEditReview extends AsyncNotifier<LineEditState> {
  LineEditReview(this.key);
  final LineEditKey key;

  bool get _outline => key.subject == 'outline';

  @override
  Future<LineEditState> build() async {
    ref.onDispose(() => _autoDone?.cancel());
    final job = await getJob(key.projectId, key.jobId);
    final result = EditPassResult.tryParse(job.result);
    if (result == null) throw ServerError('not_found', 404, 'This pass left no notes.');
    final subject = await _read();
    return LineEditState(
      jobId: job.id,
      result: result,
      text: subject.text,
      version: subject.version,
      notes: [for (final note in result.notes) ReviewedNote(note)],
    );
  }

  Future<SubjectText> _read() async {
    if (_outline) return (text: (await getAuthoredOutline(key.projectId)).text, version: null);
    final doc = await getDocument(key.projectId, key.subject);
    return (text: doc.content, version: doc.version);
  }

  Future<SubjectText> _write(String text, int? version) async {
    if (_outline) return (text: (await putAuthoredOutlineText(key.projectId, text)).text, version: null);
    final doc = await putDocument(key.projectId, key.subject, text, baseVersion: version);
    return (text: doc.content, version: doc.version);
  }

  void previous() => _move(-1);
  void next() => _move(1);

  void _move(int step) {
    final s = state.value;
    if (s == null || s.notes.isEmpty) return;
    final count = s.notes.length;
    state = AsyncData(s.copyWith(index: (s.index + step + count) % count, clearError: true));
  }

  Future<void> accept() async {
    final s = state.value;
    if (s == null || s.saving || s.current.verdict != NoteVerdict.pending) return;
    state = AsyncData(s.copyWith(saving: true, clearError: true));
    try {
      final written = await _applyTo((text: s.text, version: s.version), s.current.note);
      if (written == null) {
        state = AsyncData(s.copyWith(saving: false));
        return;
      }
      _settle(written, NoteVerdict.accepted);
    } on ServerError catch (e) {
      if (e.code != 'version_conflict') {
        state = AsyncData(s.copyWith(saving: false, error: messageFor(e)));
        return;
      }
      // Written elsewhere since this page read it. The quote is the address,
      // not the offset, so read again and try once more against the new copy.
      try {
        final fresh = await _read();
        final written = await _applyTo(fresh, s.current.note);
        if (written == null) {
          state = AsyncData(s.copyWith(saving: false, text: fresh.text, version: fresh.version));
          return;
        }
        _settle(written, NoteVerdict.accepted);
      } catch (e) {
        state = AsyncData(s.copyWith(saving: false, error: messageFor(e)));
      }
    } catch (e) {
      state = AsyncData(s.copyWith(saving: false, error: messageFor(e)));
    }
  }

  void reject() {
    final s = state.value;
    if (s == null || s.saving || s.current.verdict != NoteVerdict.pending) return;
    _settle((text: s.text, version: s.version), NoteVerdict.rejected);
  }

  /// Null when the note no longer applies to `subject` — nothing written.
  Future<SubjectText?> _applyTo(SubjectText subject, EditNote note) async {
    final resolved = resolveNote(subject.text, note.quote, note.suggestion);
    if (resolved is! Applicable) return null;
    final before = subject.text.substring(0, resolved.range.from);
    final mode = ref.read(projectProvider(key.projectId)).value?.project.typography ?? TypographyMode.curly;
    final replaced = before + applyTypography(resolved.proposed, before, mode) + subject.text.substring(resolved.range.to);
    return _write(replaced, subject.version);
  }

  /// Record the verdict on the current note and move to the next one still
  /// waiting, in reading order after it.
  void _settle(SubjectText subject, NoteVerdict verdict) {
    final s = state.value!;
    final notes = [
      for (var i = 0; i < s.notes.length; i++) i == s.index ? ReviewedNote(s.notes[i].note, verdict) : s.notes[i],
    ];
    var index = s.index;
    for (var step = 1; step <= notes.length; step++) {
      final candidate = (s.index + step) % notes.length;
      if (notes[candidate].verdict == NoteVerdict.pending) {
        index = candidate;
        break;
      }
    }
    state = AsyncData(s.copyWith(text: subject.text, version: subject.version, notes: notes, index: index, saving: false));
    if (_outline && verdict == NoteVerdict.accepted) ref.invalidate(authoredOutlineProvider(key.projectId));
    if (notes.every((n) => n.verdict != NoteVerdict.pending)) _closeAfterBeat();
  }

  Timer? _autoDone;

  /// The last verdict's Done, a beat later so it can be read as the last
  /// verdict first. The review may be left before the beat is up (the page
  /// popped, the provider gone) — then there is nothing to close.
  void _closeAfterBeat() {
    _autoDone?.cancel();
    _autoDone = Timer(_autoDoneDelay, () {
      if (ref.mounted) done();
    });
  }

  /// Close the review: the row goes, and the notes with it.
  Future<void> done() async {
    try {
      await dismissJob(key.projectId, key.jobId);
    } catch (_) {
      // A row already gone is the outcome asked for; anything else leaves
      // the notes to come back next time, which is harmless.
    }
    ref.invalidate(editPassJobProvider((projectId: key.projectId, subject: key.subject)));
  }
}
