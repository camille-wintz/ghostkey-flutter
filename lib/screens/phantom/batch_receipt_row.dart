import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/review/providers.dart';
import '../../ds/tokens.dart';
import '../../server/chat/batches.dart';
import '../../server/dto/batch.dart';
import '../../server/dto/chat.dart';
import '../../ui/press.dart';
import '../../ui/sheet.dart';
import 'review/review_screen.dart';

/// A batch an answer started, read off the server: it outlives the answer, and
/// the line follows it. A tap opens its page. A batch waiting on the author's
/// answer asks here, the moment the line appears, since nothing beside the chat
/// is on screen to ask from.
class BatchReceiptRow extends ConsumerStatefulWidget {
  const BatchReceiptRow({super.key, required this.projectId, required this.batch});
  final String projectId;
  final ChatBatchStart batch;

  @override
  ConsumerState<BatchReceiptRow> createState() => _BatchReceiptRowState();
}

class _BatchReceiptRowState extends ConsumerState<BatchReceiptRow> {
  bool _asked = false;

  BatchKey get _key => (projectId: widget.projectId, batchId: widget.batch.id);

  void _ask() {
    if (_asked) return;
    _asked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final apply = await showApplySheet(context);
      if (apply == null) {
        await cancelWaitingBatch(widget.projectId, widget.batch.id);
      } else {
        await startBatch(widget.projectId, widget.batch.id, apply: apply);
      }
      if (mounted) ref.invalidate(batchProvider(_key));
    });
  }

  void _open() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReviewScreen(
            projectId: widget.projectId,
            view: ChatView(kind: ChatViewKind.batch, id: widget.batch.id, title: widget.batch.label),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(batchProvider(_key)).value;
    if (page?.status == BatchStatus.waiting) _ask();
    final color = switch (page?.status) {
      BatchStatus.done => Ds.done,
      BatchStatus.paused => Ds.destructive,
      _ => Ds.attention,
    };
    final count = page != null && page.total > 1 ? ' · ${page.finished} of ${page.total}' : '';
    return Press(
      onPressed: _open,
      builder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(LucideIcons.penLine, size: 13, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${widget.batch.label}$count',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsStyle.ui(DsText.ui, color: Ds.mid),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 13, color: Ds.faint),
          ],
        ),
      ),
    );
  }
}

/// Asked once per account: how a line edit's changes should land. Null when the
/// author closed it without answering.
Future<bool?> showApplySheet(BuildContext context) => showGkSheet<bool>(
      context,
      header: SheetHeader(eyebrow: 'Line edits', onClose: () => Navigator.of(context).pop()),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('How should line edits land?', style: DsStyle.prose(DsText.title, color: Ds.hi)),
            const SizedBox(height: 4),
            Text("You can change this in the chat's settings.", style: DsStyle.ui(DsText.ui, color: Ds.mid)),
            const SizedBox(height: 16),
            _ApplyOption(
              title: 'Let me review them',
              detail: 'Your text stays as it is. Each change waits as a note under its chapter, to apply or dismiss.',
              onPressed: () => Navigator.of(sheet).pop(false),
            ),
            const SizedBox(height: 8),
            _ApplyOption(
              title: 'Apply them directly',
              detail: 'Fixes go straight into your text. The book is tagged first, and you can undo any chapter.',
              onPressed: () => Navigator.of(sheet).pop(true),
            ),
          ],
        ),
      ),
    );

class _ApplyOption extends StatelessWidget {
  const _ApplyOption({required this.title, required this.detail, required this.onPressed});
  final String title;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        builder: (_, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Ds.panel, borderRadius: BorderRadius.circular(DsGeom.radius)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: DsStyle.ui(DsText.body, color: Ds.hi)),
              const SizedBox(height: 2),
              Text(detail, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
            ],
          ),
        ),
      );
}
