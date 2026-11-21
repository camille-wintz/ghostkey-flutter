import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/room_back_button.dart';
import '../../ui/text.dart';
import '../../veil/entity_interview.dart';
import '../../veil/providers.dart';
import '../../veil/roster.dart';
import 'interview_card_sheet.dart';
import 'interview_dots.dart';

/// The card interview as a screen of its own, after the site's character
/// interview with the cat left out: the question set large, the author's
/// answer under it, and the card filling in below as each answer is filed —
/// the description, a GMC cell, the dossier, wherever the question pointed.
/// Both "Answer questions" buttons open it. Leaving it any way files a typed
/// answer first; every other answer is already on the card. The desk's
/// `BibleInterviewStage`.
Future<void> openEntityInterview(BuildContext context, {required String projectId, required BibleEntity entity}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EntityInterviewScreen(projectId: projectId, entityId: entity.id)),
    );

class EntityInterviewScreen extends ConsumerStatefulWidget {
  const EntityInterviewScreen({super.key, required this.projectId, required this.entityId});
  final String projectId;
  final String entityId;

  @override
  ConsumerState<EntityInterviewScreen> createState() => _EntityInterviewScreenState();
}

class _EntityInterviewScreenState extends ConsumerState<EntityInterviewScreen> {
  final _answer = TextEditingController();
  late final _interview = EntityInterview(ref, widget.projectId, widget.entityId);
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  /// Ask the sitting's first question; a spent count leaves, the app's quota
  /// notice saying why.
  Future<void> _open() async {
    await _interview.start();
    if (_interview.quotaRefused) _leave();
  }

  @override
  void dispose() {
    _interview.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _leave() {
    if (!mounted || _closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  Future<void> _next({bool skip = false}) async {
    if (await _interview.next(skip ? '' : _answer.text)) _answer.clear();
  }

  Future<void> _finish() async {
    if (_interview.busy || _closing) return;
    if (await _interview.finish(_answer.text)) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final bible = ref.watch(bibleProvider(widget.projectId)).value;
    final entity = bible?.entities.where((e) => e.id == widget.entityId).firstOrNull;
    final dossier = entity == null ? null : ref.watch(dossiersProvider(widget.projectId)).value?[entity.key];

    return ListenableBuilder(
      listenable: Listenable.merge([_interview, _answer]),
      builder: (context, _) {
        final question = _interview.question;
        final busy = _interview.busy;
        final waiting = busy || question == null;
        return PopScope(
          canPop: _closing || (!busy && _answer.text.trim().isEmpty),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_finish());
          },
          child: Scaffold(
            backgroundColor: Ds.void_,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 10, 16, 4),
                    child: Row(
                      children: [
                        RoomBackButton(onPressed: () => unawaited(_finish()), semanticLabel: 'Back to the card'),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Eyebrow('Questions'),
                              Text(
                                titleCase(entity?.name ?? ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsStyle.prose(DsText.body, color: Ds.hi),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        Row(
                          children: [
                            Eyebrow('Question ${_interview.trail.length + 1}'),
                            const SizedBox(width: 12),
                            Expanded(child: InterviewDots(trail: _interview.trail)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            question?.question ?? (busy ? 'Thinking of a question…' : ''),
                            style: DsStyle.prose(DsText.title, color: Ds.hi).copyWith(height: 1.25),
                          ),
                        ),
                        if (question != null && question.heading.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Files under ${question.heading}',
                            style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                        const SizedBox(height: 24),
                        GkField(
                          controller: _answer,
                          placeholder: 'Your answer, in your words',
                          autofocus: true,
                          enabled: !waiting,
                          minLines: 4,
                          maxLines: 12,
                          maxLength: 4000,
                        ),
                        if (_interview.error case final error?) ...[
                          const SizedBox(height: 12),
                          UiText(error, step: DsText.ui, color: Ds.destructive),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            GkButton(
                              label: 'Skip',
                              variant: ButtonVariant.outline,
                              disabled: waiting,
                              onPressed: () => unawaited(_next(skip: true)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GkButton(
                                label: 'Next question',
                                busy: busy,
                                disabled: question == null,
                                onPressed: () => unawaited(_next()),
                              ),
                            ),
                          ],
                        ),
                        if (entity != null) ...[
                          const SizedBox(height: 36),
                          InterviewCardSheet(entity: entity, dossier: dossier),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
