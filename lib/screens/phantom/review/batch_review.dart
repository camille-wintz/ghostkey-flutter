import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../chat/review/providers.dart';
import '../../../ds/tokens.dart';
import '../../../server/chat/batches.dart';
import '../../../server/dto/batch.dart';
import '../../../server/dto/chat.dart';
import '../../../server/errors.dart';
import '../../../ui/button.dart';
import '../../../ui/press.dart';
import '../../../ui/state_screen.dart';
import '../../../ui/text.dart';
import 'review_screen.dart';

/// A batch's page: how far it has got, large, then each chapter. A chapter opens
/// where its notes or its changes are. The word-by-word changes are the desk's.
class BatchReview extends ConsumerStatefulWidget {
  const BatchReview({super.key, required this.projectId, required this.batchId});
  final String projectId;
  final String batchId;

  @override
  ConsumerState<BatchReview> createState() => _BatchReviewState();
}

class _BatchReviewState extends ConsumerState<BatchReview> {
  /// The run a stop was asked of: "stopping" lasts as long as that run does.
  String? _stoppedJob;
  bool _busy = false;
  String? _error;

  BatchKey get _key => (projectId: widget.projectId, batchId: widget.batchId);

  Future<void> _do(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(batchProvider(_key));
  }

  void _stop(String jobId) {
    _stoppedJob = jobId;
    _do(() => stopBatch(widget.projectId, jobId));
  }

  void _openChapter(BatchItem item) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReviewScreen(
            projectId: widget.projectId,
            view: ChatView(kind: ChatViewKind.chapter, id: item.opens ?? item.subject, title: item.label),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(batchProvider(_key));
    final page = async.value;
    if (page == null) {
      return async.hasError
          ? const StateScreen(message: 'This one could not be read.')
          : const StateScreen(spinner: true, message: 'Reading where it stands…');
    }
    final stopping = _stoppedJob != null && _stoppedJob == page.jobId && page.status == BatchStatus.running;
    final waiting = page.items.where((i) => i.waiting).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        BrandTitle(page.total == 1 ? page.label : '${page.finished} of ${page.total}'),
        const SizedBox(height: 6),
        Text(_line(page, stopping), style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic)),
        if (page.failed > 0) ...[
          const SizedBox(height: 4),
          UiText('${page.failed} failed, and ${page.failed == 1 ? "wasn't" : "weren't"} charged.', step: DsText.ui, color: Ds.low),
        ],
        if (_error case final error?) ...[
          const SizedBox(height: 8),
          UiText(error, step: DsText.ui, color: Ds.destructive),
        ],
        const SizedBox(height: 16),
        if (page.status == BatchStatus.running && !stopping && page.jobId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: GkButton(label: 'Stop', variant: ButtonVariant.outline, disabled: _busy, onPressed: () => _stop(page.jobId!)),
          ),
        if (page.status == BatchStatus.paused && page.pauseReason != 'draft_changed')
          Align(
            alignment: Alignment.centerLeft,
            child: GkButton(
              label: page.pauseReason == 'review_missed' ? 'Review it now' : 'Resume',
              busy: _busy,
              onPressed: () => _do(() => resumeBatch(widget.projectId, widget.batchId)),
            ),
          ),
        const SizedBox(height: 16),
        for (final item in page.items.where((i) => !i.waiting))
          _ItemRow(
            item: item,
            disabled: _busy,
            onOpen: () => _openChapter(item),
            onUndo: () => _do(() => undoBatchItem(widget.projectId, widget.batchId, item.seq)),
          ),
        if (waiting.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Eyebrow('Still to come'),
          const SizedBox(height: 8),
          for (final item in waiting)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsStyle.ui(DsText.ui, color: item.status == 'running' ? Ds.attention : Ds.mid),
              ),
            ),
        ],
      ],
    );
  }

  static String _line(BatchPage page, bool stopping) {
    if (stopping) return "Stopping after what's in progress. It's paid for, so it lands.";
    return switch (page.status) {
      BatchStatus.waiting => "It starts when you've said how the changes should land.",
      BatchStatus.running => page.runningLine ?? (page.applies == true ? 'Going through them now, and writing the fixes in.' : 'Going through them now, and leaving notes.'),
      BatchStatus.reviewing => 'All through. The chat is reading what it did.',
      BatchStatus.done => page.doneLine ?? (page.applies == true ? 'All through, and written in.' : 'All through. Your text is unchanged, and the notes wait under each chapter.'),
      BatchStatus.paused => switch (page.pauseReason) {
          'credits' => "You're out of credits. The rest are untouched, and this picks up where it stopped.",
          'draft_changed' => "The book moved to another draft, so this can't go on.",
          'review_missed' => "Finished, but the chat hasn't read it through yet.",
          'item_failed' => 'One failed, and the ones after it depend on it.',
          'interrupted' => 'It was interrupted. The rest are untouched.',
          _ => 'Stopped. The rest are untouched.',
        },
      BatchStatus.unknown => '',
    };
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.disabled, required this.onOpen, required this.onUndo});
  final BatchItem item;
  final bool disabled;
  final VoidCallback onOpen;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final failed = item.status == 'failed';
    final detail = failed ? 'Failed' : (item.undone ? 'Put back' : (item.summary ?? ''));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Press(
            onPressed: failed ? null : onOpen,
            builder: (_, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Ds.panel, borderRadius: BorderRadius.circular(DsGeom.radius)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsStyle.ui(DsText.body, color: Ds.hi)),
                  ),
                  const SizedBox(width: 8),
                  Text(detail, style: DsStyle.ui(DsText.ui, color: failed ? Ds.destructive : Ds.mid)),
                ],
              ),
            ),
          ),
          for (final note in item.open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 0, 0),
              child: Text(note.quote.isEmpty ? note.note : '«${note.quote}» ${note.note}', style: DsStyle.ui(DsText.ui, color: Ds.mid)),
            ),
          if (item.canUndo)
            Press(
              onPressed: disabled ? null : onUndo,
              builder: (_, _) => Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.undo2, size: 14, color: Ds.low),
                    const SizedBox(width: 6),
                    Text('Undo this chapter', style: DsStyle.ui(DsText.ui, color: Ds.low)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
