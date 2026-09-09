import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/composer.dart';
import '../../chat/models.dart';
import '../../chat/providers.dart';
import '../../chat/quota_feature.dart';
import '../../chat/refusals.dart';
import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/providers.dart';
import 'attachment_tray.dart';
import 'chapter_picker_sheet.dart';
import 'chat_composer.dart';
import 'chat_intro.dart';
import 'chat_thread.dart';
import 'chat_top_bar.dart';
import 'error_bar.dart';
import 'long_thread_note.dart';
import 'model_sheet.dart';
import 'plan_notice.dart';
import 'quota_notice.dart';

/// Top bar (menu · title · model chip) · the thread · the pending turn ·
/// composer. The Scaffold above it owns the drawer and the keyboard inset.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String get _projectId => widget.projectId;

  /// Session-wide, not persisted; applied per send.
  String _model = defaultModel;

  late final ComposerController _composer = ComposerController(
    spentIds: () => [
      for (final m in ref.read(chatTurnProvider(_projectId)).messages)
        for (final a in m.attachments) a.id,
    ],
    quotaFor: (model) => chatQuotaFor(ref.read(quotaProvider).value, model),
    sendTurn: (text, attachments, model) => ref.read(chatTurnProvider(_projectId).notifier).send(text, attachments, model),
    isSending: () => ref.read(chatTurnProvider(_projectId)).sending,
  );
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The thread is reversed, so its bottom is offset 0.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _send([String? override]) async {
    _scrollToEnd();
    final refusal = await _composer.send(override: override, model: _model);
    if (refusal == null || !mounted) return;
    switch (refusal) {
      case QuotaRefusal(:final feature, :final refused):
        await showQuotaNotice(
          context,
          snapshot: ref.read(quotaProvider).value?.feature(feature),
          refused: refused,
        );
      case PlanDenied():
        await showPlanNotice(context, refusal);
    }
  }

  Future<void> _pickModel() async {
    final picked = await showModelSheet(context, model: _model);
    if (picked != null && mounted) setState(() => _model = picked);
  }

  Future<void> _attach() async {
    final doc = await showChapterPickerSheet(
      context,
      projectId: _projectId,
      attachedDocumentIds: _composer.attachedDocumentIds,
    );
    if (doc != null) _composer.attachChapter(doc);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatTurnProvider(_projectId));
    final turn = ref.read(chatTurnProvider(_projectId).notifier);
    final chapters = ref.watch(projectProvider(_projectId)).value?.chapters;
    final planning = chapters != null && chaptersInTree(chapters).isEmpty;
    final sessions = ref.watch(chatSessionsProvider(_projectId)).value;
    final activeId = chat.activeSessionId;
    final title = activeId == null
        ? 'New chat'
        : (sessions?.where((s) => s.id == activeId).firstOrNull?.title ?? 'Chat');

    // A turn starting or a session opening is the one time the thread must
    // show its end regardless of where the author had scrolled.
    ref.listen(chatTurnProvider(_projectId).select((s) => (s.messages.length, s.activeSessionId)), (_, _) => _scrollToEnd());

    return ColoredBox(
      color: Ds.void_,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ChatTopBar(
              title: title,
              modelName: modelName(_model),
              onMenu: () => Scaffold.of(context).openDrawer(),
              onModel: _pickModel,
            ),
            Expanded(
              child: ChatThread(
                messages: chat.messages,
                stepsByIndex: chat.stepsByIndex,
                notesByIndex: chat.notesByIndex,
                pending: chat.pending,
                controller: _scroll,
                intro: ChatIntro(planning: planning, onPick: _send, disabled: chat.sending),
              ),
            ),
            if (chat.error case final error?) ErrorBar(message: error, onDismiss: turn.clearError),
            if (chat.messages.length > longThread) const LongThreadNote(),
            ListenableBuilder(
              listenable: _composer,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AttachmentTray(attachments: _composer.attachments, onRemove: _composer.remove),
                  ChatComposerBar(
                    controller: _composer.text,
                    pasteInterceptor: _composer.pasteInterceptor,
                    onSend: _send,
                    onStop: turn.stop,
                    onAttach: _attach,
                    sending: chat.sending,
                    canSend: _composer.canSend,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
