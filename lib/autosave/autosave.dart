import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../server/dto/projects.dart';
import '../server/projects/api.dart';
import 'draft_journal.dart';

/// How often dirty text goes to the server.
const Duration autosaveInterval = Duration(seconds: 5);

/// How long after the last keystroke the journal is written.
const Duration draftWriteDebounce = Duration(seconds: 1);

/// The single owner of "editor text reaches the server", for ONE document —
/// the RN `useAutosave` with its ids fixed at construction. Flushes on an
/// interval, on app background/lock, and on [dispose] (which is the chapter
/// switch and the room exit: the outgoing editor's autosave is disposed
/// before the next one exists, and its ids are its own). Journals dirty text
/// to disk so a process kill loses nothing: the draft is restored on the
/// next open if the server still holds the revision it was typed against.
///
/// Saves go through the raw `putDocument` call, never through a provider, so
/// nothing re-reads the document under the author's typing.
class Autosave with WidgetsBindingObserver {
  Autosave({
    required this.projectId,
    required this.documentId,
    required TextEditingController text,
    required this.onSaved,
    required this.onRestore,
    DraftJournal? journal,
    Future<DocumentDto> Function(String projectId, String documentId, String content)? save,
  })  : _text = text,
        _journal = journal ?? DraftJournal(),
        _save = save ?? putDocument {
    _seen = text.text;
    _text.addListener(_onText);
    _tick = Timer.periodic(autosaveInterval, (_) => flush());
    WidgetsBinding.instance.addObserver(this);
  }

  final String projectId;
  final String documentId;
  final TextEditingController _text;
  final DraftJournal _journal;

  /// The write itself — `putDocument`, or a test's stand-in.
  final Future<DocumentDto> Function(String projectId, String documentId, String content) _save;

  /// A write landed — the caller refreshes what reads word counts.
  final void Function(DocumentDto doc) onSaved;

  /// A leftover draft is being put back into the editor.
  final void Function(String content) onRestore;

  /// A write is in flight.
  final ValueNotifier<bool> saving = ValueNotifier(false);

  /// Everything typed is on the server. Mid-save counts as unsaved — the
  /// tick appears when the write has actually landed.
  final ValueNotifier<bool> saved = ValueNotifier(false);

  /// Last server-confirmed content; null until the document has loaded.
  String? _savedText;
  int _serverVersion = 0;
  String? _inFlight;
  String _seen = '';
  Timer? _tick;
  Timer? _journalTimer;

  /// Journal writes and deletes, in order: a background write and the
  /// delete of the flush it precedes must not race on the file.
  Future<void> _journalOps = Future.value();
  bool _restored = false;
  bool _disposed = false;

  bool get _dirty => _savedText != null && _text.text != _savedText;

  /// The server copy has been put into the editor. Called once.
  void loaded(DocumentDto doc) {
    _savedText = doc.content;
    _serverVersion = doc.version;
    _refreshSaved();
    unawaited(_restoreDraft(doc));
  }

  /// Send dirty text now. A flush already carrying this exact text is left
  /// to land; a failed one leaves `_savedText` stale so the next tick retries.
  void flush() {
    final current = _text.text;
    final savedText = _savedText;
    if (savedText == null || current == savedText) return;
    if (_inFlight == current) return;
    _inFlight = current;
    _set(saving, true);
    _refreshSaved();
    _save(projectId, documentId, current).then((doc) {
      _serverVersion = doc.version;
      _savedText = current;
      unawaited(_deleteJournal());
      if (kDebugMode) debugPrint('[autosave] Flushed (${current.length} chars)');
      onSaved(doc);
    }).catchError((Object e) {
      debugPrint('[autosave] Flush failed — will retry on next tick: $e');
    }).whenComplete(() {
      if (_inFlight == current) _inFlight = null;
      _set(saving, false);
      _refreshSaved();
    });
  }

  void _onText() {
    final current = _text.text;
    if (identical(current, _seen) || current == _seen) return;
    _seen = current;
    _refreshSaved();
    _journalTimer?.cancel();
    if (!_dirty) return;
    // Journal dirty text as it's typed (debounced), so even a hard kill with
    // no background transition loses at most the debounce window.
    _journalTimer = Timer(draftWriteDebounce, () => unawaited(_writeJournal(current)));
  }

  Future<void> _writeJournal(String content) {
    final draft = DocumentDraft(content: content, baseVersion: _serverVersion, savedAt: DateTime.now().millisecondsSinceEpoch);
    return _journalOps = _journalOps.then((_) => _journal.write(projectId, documentId, draft));
  }

  Future<void> _deleteJournal() => _journalOps = _journalOps.then((_) => _journal.delete(projectId, documentId));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused && state != AppLifecycleState.inactive && state != AppLifecycleState.hidden) {
      return;
    }
    // Going idle: journal first (the OS may kill the process before any
    // network finishes), then try the real flush in the background grace
    // window.
    if (_dirty) unawaited(_writeJournal(_text.text));
    flush();
  }

  // Once per opened document, after the server copy has loaded into the
  // editor: restore a leftover draft — it only exists because a flush never
  // landed. Restoring marks the editor dirty, so the next tick flushes it.
  Future<void> _restoreDraft(DocumentDto doc) async {
    if (_restored) return;
    _restored = true;
    final draft = await _journal.read(projectId, documentId);
    if (_disposed || draft == null) return;
    if (draft.baseVersion != doc.version || draft.content == doc.content) {
      await _deleteJournal();
      return;
    }
    if (_text.text != doc.content) return; // author already typed
    if (kDebugMode) debugPrint('[autosave] Restored draft (${draft.content.length} chars)');
    onRestore(draft.content);
  }

  void _refreshSaved() {
    if (_disposed) return;
    _set(saved, _savedText != null && !saving.value && _text.text == _savedText);
  }

  void _set(ValueNotifier<bool> notifier, bool value) {
    if (!_disposed) notifier.value = value;
  }

  /// Flushes what is dirty, then stops. The flush in flight outlives this
  /// object on purpose — it is the chapter-switch and room-exit save.
  void dispose() {
    if (_disposed) return;
    _journalTimer?.cancel();
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _text.removeListener(_onText);
    flush();
    _disposed = true;
    saving.dispose();
    saved.dispose();
  }
}
