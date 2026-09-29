import 'package:flutter/foundation.dart';

import '../server/dto/chat.dart';
import '../server/dto/chat_conversation.dart';

// A running answer as the phone holds it: the words and the tool steps so
// far, fed by `chat_stream` frames. Two ValueNotifiers, so a frame changes a
// value the one bubble drawing the answer listens to — nothing rebuilds the
// thread per frame (the conversation's own state changes when a message is
// added or its status moves, not on every word).
//
// Nothing here trusts that it saw every frame. A frame says where its words
// start (`at`) and its number (`n`); a hole in either, or a beat reporting
// more words than are held, is answered with a re-read of the conversation,
// never by drawing around the hole. A read does not say which frame it
// corresponds to, and the row it returns is flushed only every second or two,
// so after a read the frames heard for the answer are laid over the row again
// — which is what keeps a read mid-answer from falling behind the live words.

/// What a frame asks of the conversation.
enum FrameVerdict {
  applied,

  /// A frame was missed: read the conversation now.
  reread,

  /// Words are missing that the row has not been flushed with yet, perhaps:
  /// read the conversation once the next flush is due.
  rereadSoon,
}

/// Words a beat may count that no frame has carried yet: what the server
/// batches for 250 ms before sending, at most one frame's worth.
const int _inFlight = 1500;

class LiveAnswer {
  LiveAnswer({this.id, String text = '', List<ChatToolStep> steps = const []})
      : text = ValueNotifier(text),
        steps = ValueNotifier(steps);

  /// The answer's message id — null while the turn has not started and its
  /// row does not exist yet (the wait between a send and the answer).
  final String? id;

  /// The prose so far. Cleared only by a discard: narration before a tool
  /// call is part of the answer.
  final ValueNotifier<String> text;
  final ValueNotifier<List<ChatToolStep>> steps;

  /// The last frame number applied. Null after a read, which does not say
  /// which frame it corresponds to: the next one to arrive is the baseline.
  int? _lastN;

  FrameVerdict apply(ChatStreamFrame frame) {
    final last = _lastN;
    // A frame already applied (or older): it has nothing to add.
    if (last != null && frame.n <= last) return FrameVerdict.applied;
    _lastN = frame.n;
    final gap = last != null && frame.n != last + 1;
    final verdict = switch (frame) {
      StreamText(text: final words, :final at) => _write(words, at) ? FrameVerdict.applied : FrameVerdict.rereadSoon,
      StreamDiscard() => _clear(),
      StreamStep(:final step) => _step(step),
      StreamBeat(:final textLength) =>
        textLength > text.value.length + _inFlight ? FrameVerdict.rereadSoon : FrameVerdict.applied,
      StreamView() || StreamOther() => FrameVerdict.applied,
    };
    return gap ? FrameVerdict.reread : verdict;
  }

  /// Take the conversation's copy of this answer, then lay the frames [heard]
  /// for it over the row in order — the ones older than the row's flush
  /// rewrite what it already has, the newer ones carry it forward. Frame
  /// numbers are not checked here (a gap among them is why the read was
  /// made); a hole in the words is, and asks for a later read.
  FrameVerdict settle(ChatMessage row, [Iterable<ChatStreamFrame> heard = const []]) {
    var words = row.text;
    var trace = row.steps;
    var hole = false;
    int? lastN;
    for (final frame in heard.toList()..sort((a, b) => a.n.compareTo(b.n))) {
      lastN = frame.n;
      switch (frame) {
        case StreamText(text: final chunk, :final at):
          if (at == null) {
            words += chunk;
          } else if (at <= words.length) {
            words = words.substring(0, at) + chunk;
          } else {
            hole = true;
          }
        case StreamDiscard():
          words = '';
        case StreamStep(:final step):
          trace = mergeSteps(trace, [step]);
        case StreamBeat() || StreamView() || StreamOther():
          break;
      }
    }
    _lastN = lastN;
    text.value = words;
    steps.value = trace;
    return hole ? FrameVerdict.rereadSoon : FrameVerdict.applied;
  }

  /// False when words were missed between what is held and where these start.
  bool _write(String words, int? at) {
    final held = text.value;
    if (at == null) {
      text.value = held + words;
      return true;
    }
    if (at > held.length) return false;
    text.value = held.substring(0, at) + words;
    return true;
  }

  FrameVerdict _clear() {
    text.value = '';
    return FrameVerdict.applied;
  }

  FrameVerdict _step(ChatToolStep step) {
    steps.value = upsertStep(steps.value, step);
    return FrameVerdict.applied;
  }
}

/// A step arrives twice — `running`, then `done` / `error` — keyed by tool +
/// summary.
List<ChatToolStep> upsertStep(List<ChatToolStep> steps, ChatToolStep step) {
  final at = steps.indexWhere((s) => _same(s, step));
  if (at == -1) return [...steps, step];
  return [for (var i = 0; i < steps.length; i++) i == at ? step : steps[i]];
}

/// The row's steps with the heard ones laid over them — a heard step only
/// where the row has none, or has it still running: the row may be newer.
List<ChatToolStep> mergeSteps(List<ChatToolStep> row, List<ChatToolStep> held) {
  var merged = row;
  for (final step in held) {
    final at = merged.indexWhere((s) => _same(s, step));
    if (at == -1 || merged[at].status == ChatToolStepStatus.running) merged = upsertStep(merged, step);
  }
  return merged;
}

bool _same(ChatToolStep a, ChatToolStep b) => a.tool == b.tool && a.summary == b.summary;
