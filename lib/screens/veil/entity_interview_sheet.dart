import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/sheet.dart';
import '../../ui/text.dart';
import '../../veil/entity_interview.dart';
import '../../veil/roster.dart';

/// The dossier interview for one card, in a sheet: the question, the
/// author's answer, and the three ways on — Next question (file it and ask
/// another), Skip, and Done. What they write lands in the dossier as they
/// wrote it, under the question's heading; the page behind re-reads it.
/// Closing the sheet any way ends the sitting and files a typed answer first
/// — the desk's `BibleInterviewPanel`.
Future<void> showEntityInterview(BuildContext context, {required String projectId, required BibleEntity entity}) =>
    showGkSheet<void>(
      context,
      maxHeightFraction: 0.9,
      builder: (context) => _EntityInterviewSheet(projectId: projectId, entity: entity),
    );

class _EntityInterviewSheet extends ConsumerStatefulWidget {
  const _EntityInterviewSheet({required this.projectId, required this.entity});
  final String projectId;
  final BibleEntity entity;

  @override
  ConsumerState<_EntityInterviewSheet> createState() => _EntityInterviewSheetState();
}

class _EntityInterviewSheetState extends ConsumerState<_EntityInterviewSheet> {
  final _answer = TextEditingController();
  late final _interview = EntityInterview(ref, widget.projectId, widget.entity.id);
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_interview.start());
  }

  @override
  void dispose() {
    _interview.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _next({bool skip = false}) async {
    if (await _interview.next(skip ? '' : _answer.text)) _answer.clear();
  }

  Future<void> _finish() async {
    if (_interview.busy || _closing) return;
    if (!await _interview.finish(_answer.text) || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_interview, _answer]),
        builder: (context, _) {
          final question = _interview.question;
          final busy = _interview.busy;
          return PopScope(
            canPop: _closing || (!busy && _answer.text.trim().isEmpty),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) unawaited(_finish());
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(eyebrow: 'Questions', trailing: titleCase(widget.entity.name), onClose: _finish),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          question?.question ?? (busy ? 'Thinking of a question…' : ''),
                          style: DsStyle.prose(DsText.title, color: Ds.hi),
                        ),
                        if (question != null && question.heading.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          UiText('Files under ${question.heading}', step: DsText.ui, color: Ds.low),
                        ],
                        const SizedBox(height: 16),
                        GkField(
                          controller: _answer,
                          placeholder: 'Your answer, in your words',
                          autofocus: true,
                          enabled: !busy && question != null,
                          minLines: 3,
                          maxLines: 8,
                          maxLength: 4000,
                        ),
                        if (_interview.error case final error?) ...[
                          const SizedBox(height: 12),
                          UiText(error, step: DsText.ui, color: Ds.destructive),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            GkButton(label: 'Done', variant: ButtonVariant.outline, disabled: busy, onPressed: _finish),
                            const SizedBox(width: 8),
                            GkButton(
                              label: 'Skip',
                              variant: ButtonVariant.outline,
                              disabled: busy || question == null,
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}
