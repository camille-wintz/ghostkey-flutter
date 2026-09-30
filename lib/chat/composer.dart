import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/words.dart';
import '../server/dto/billing.dart';
import '../server/dto/chat.dart';
import '../server/dto/projects.dart';
import '../server/dto/media.dart';
import 'attachments.dart';
import 'quota_feature.dart';
import 'refusals.dart';
import 'conversation.dart';

// Everything between the keyboard and the conversation owner's `send`: the
// text and its paste rule, the attachments and their handles, and the quota
// gate on both sides of the call — ahead of it from the cached snapshot (so a
// spent counter explains itself without drawing a message that comes
// straight back), and after it from the server's 402/403 (the one that must
// exist; the snapshot can be stale). The words leave the composer only when
// the server has them: a refused or undelivered message is still there to
// send again.
//
// Its dependencies are functions rather than providers so the gate is
// testable without a ProviderScope.

class ComposerController extends ChangeNotifier {
  ComposerController({
    required this.spentIds,
    required this.quotaFor,
    required this.sendTurn,
    required this.isBusy,
  }) {
    text.addListener(notifyListeners);
  }

  /// Handles the conversation has already spent, so a new one is unique
  /// across the whole session and the model never sees two "a2"s.
  final List<String> Function() spentIds;
  /// The chat's line, read at the send. Every model draws on the same one.
  final ChatQuotaFeature Function() quotaFor;
  /// `model` is the author's pick — null when they have not picked, and
  /// then the turn names none and the server's default answers.
  final Future<SendOutcome> Function(String text, List<ChatAttachment> attachments, String? model) sendTurn;
  /// Sending, or the conversation answering — no message goes then.
  final bool Function() isBusy;

  final TextEditingController text = TextEditingController();

  /// Goes on the composer's TextField. Flutter has no paste event either;
  /// a paste is recognised by its size, at the one place every edit passes.
  late final TextInputFormatter pasteInterceptor = _PasteInterceptor(attachPaste);

  List<ChatAttachment> _attachments = const [];
  List<ChatAttachment> get attachments => _attachments;

  /// document_ids already attached, for the picker's dedupe.
  Set<String> get attachedDocumentIds =>
      {for (final a in _attachments) if (a is ChapterAttachment) a.documentId};

  /// Text or an attachment to send.
  bool get canSend => text.text.trim().isNotEmpty || _attachments.isNotEmpty;

  String _mint() => mintAttachmentId([...spentIds(), ..._attachments.map((a) => a.id)]);

  void _set(List<ChatAttachment> next) {
    _attachments = next;
    notifyListeners();
  }

  /// Attach an uploaded file: `upload` (the screen's, over the library's
  /// upload call) hands back the item the server made, and the attachment
  /// carries its id.
  Future<void> attachFile(Future<MediaItem> Function() upload) async => attachItem(await upload());

  /// Attach an item already in the library — an upload's, or a picture the
  /// picker handed back — by its id, the one shape the server reads. A
  /// length on the chip only for a text whose whole body came back; a
  /// picture's body is its caption, not words to count.
  void attachItem(MediaItem item) {
    if (_attachments.any((a) => a is FileAttachment && a.itemId == item.id)) return;
    _set([
      ..._attachments,
      FileAttachment(
        id: _mint(),
        title: item.title.trim().isNotEmpty ? item.title : (item.isImage ? 'Picture' : 'File'),
        itemId: item.id,
        words: !item.isImage && item.bodyIsWhole ? countWords(item.body) : null,
      ),
    ]);
  }

  void attachChapter(DocumentSummary chapter) {
    // Twice would give the model two handles for one document.
    if (_attachments.any((a) => a is ChapterAttachment && a.documentId == chapter.id)) return;
    _set([
      ..._attachments,
      ChapterAttachment(
        id: _mint(),
        title: stripMd(chapter.filename),
        documentId: chapter.id,
        words: chapter.wordCount,
      ),
    ]);
  }

  /// Take a paste as an attachment. False when it is short enough to stay
  /// text.
  bool attachPaste(String pasted) {
    if (!isLongPaste(pasted)) return false;
    final body = capPasteText(pasted);
    _set([
      ..._attachments,
      PasteAttachment(id: _mint(), title: pasteTitle(pasted), words: countWords(body), text: body),
    ]);
    return true;
  }

  void remove(String id) => _set(_attachments.where((a) => a.id != id).toList());

  void clear() => _set(const []);

  /// Send what the composer holds (or `override`, an intro suggestion or a
  /// question's answers — attachments still go with it). Null when the
  /// message went, did not get there (the conversation says why), or there
  /// was nothing to send; a refusal when a counter or the plan said no.
  Future<ComposerRefusal?> send({String? override, String? model}) async {
    if (isBusy()) return null;
    final body = (override ?? text.text).trim();
    final attached = _attachments;
    if (body.isEmpty && attached.isEmpty) return null;
    final quota = quotaFor();
    if (quota.exhausted) return QuotaRefusal(feature: quota.feature);
    final outcome = await sendTurn(body, attached, model);
    if (outcome is SendDone) {
      // An override was never in the field, so what the author is typing
      // there stays.
      if (override == null && text.text.trim() == body) text.clear();
      if (identical(_attachments, attached)) clear();
      return null;
    }
    // Not sent: an override comes back only into an empty field, to send
    // again from there.
    if (override != null && text.text.trim().isEmpty) text.text = override;
    if (outcome is! SendRefused) return null;
    final error = outcome.error;
    if (error.code == 'quota_exceeded') {
      return QuotaRefusal(feature: error.quota?.feature ?? quota.feature, refused: error.quota);
    }
    return PlanDenied(
      what: error.denial?.label ?? 'This model',
      requiredPlan: planOrNull(error.denial?.requiredPlan),
    );
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

/// A plan the ladder knows, or null — `Plan.fromWire` reads garbage as
/// `free`, which a notice must never print as the answer.
Plan? planOrNull(String? wire) {
  for (final p in Plan.values) {
    if (p.name == wire) return p;
  }
  return null;
}

/// A single edit that inserts a long run is handed to `attachPaste`, and when
/// it takes it the run leaves the field with the caret where it began.
/// Everything shorter is typing and stays. Programmatic sets (a restored
/// refusal) never pass through a formatter, so they are never re-lifted.
class _PasteInterceptor extends TextInputFormatter {
  _PasteInterceptor(this.attachPaste);
  final bool Function(String text) attachPaste;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final run = insertedRun(oldValue.text, newValue.text);
    if (run == null || !attachPaste(run.inserted)) return newValue;
    return TextEditingValue(text: run.without, selection: TextSelection.collapsed(offset: run.start));
  }
}
