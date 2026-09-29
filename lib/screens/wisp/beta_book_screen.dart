import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../core/chapter_title.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import '../../server/errors.dart';
import '../../ui/button.dart';
import '../../ui/lock_notice.dart';
import '../../ui/page_notice.dart';
import '../../ui/press.dart';
import '../../ui/room_subtitle.dart';
import '../../ui/room_title_bar.dart';
import '../../wisp/access.dart';
import '../../wisp/page_turner.dart';
import '../../wisp/providers.dart';
import 'reaction_chip.dart';
import 'report_card.dart';
import 'wisp_page_loading.dart';

/// A beta reader's comments in the margin of the book: the book one page at a
/// time, the comments on that page under it, and a comment at a time from
/// either end. The walk is [PageTurner]'s; the pages and where each comment
/// sits are the server's.
class BetaBookScreen extends ConsumerWidget {
  const BetaBookScreen({super.key, required this.projectId, required this.reader});
  final String projectId;
  final ReaderCard reader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (projectId: projectId, reader: reader.id);
    final pages = ref.watch(betaReaderPagesProvider(key));

    Widget notice(Widget child) => ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 40), children: [child]);

    final Widget body;
    if (pages.hasError && !pages.hasValue) {
      body = notice(PageNotice("The book wouldn't load: ${messageFor(pages.error)}", error: true));
    } else if (pages.value case final read?) {
      body = switch (read.book) {
        final book? when book.pages.isNotEmpty =>
          _Book(book: book, hiddenComments: read.hiddenComments, readerName: reader.name),
        _ => notice(PageNotice("${reader.name} hasn't read this book yet.")),
      };
    } else {
      body = notice(const WispPageLoading('Opening the book…'));
    }

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        child: Column(
          children: [
            RoomTitleBar(
              title: reader.name,
              subtitle: const RoomSubtitle('Comments in the margin'),
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _Book extends StatefulWidget {
  const _Book({required this.book, required this.hiddenComments, required this.readerName});
  final CommentedBook book;
  final int hiddenComments;
  final String readerName;

  @override
  State<_Book> createState() => _BookState();
}

class _BookState extends State<_Book> {
  late PageTurner _turner = PageTurner.of(widget.book);
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(_Book old) {
    super.didUpdateWidget(old);
    // A fresh read of the same book keeps the page the author was on.
    if (!identical(old.book, widget.book)) _turner = PageTurner.of(widget.book).toPage(_turner.page);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(PageTurner? next) {
    if (next == null) return;
    final turned = next.page != _turner.page;
    setState(() => _turner = next);
    if (turned && _scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = _turner;
    final page = t.openPage!;
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -250) _go(t.nextPage);
              if (v > 250) _go(t.prevPage);
            },
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _PageView(page: page, active: t.activeComment),
                const SizedBox(height: 18),
                if (t.onPage.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'No comments on this page',
                      textAlign: TextAlign.center,
                      style: DsStyle.ui(DsText.ui, color: Ds.low),
                    ),
                  ),
                for (final (:comment, :index) in t.onPage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CommentCard(
                      comment: comment,
                      active: index == t.active,
                      onPressed: () => _go(t.toComment(index)),
                    ),
                  ),
                if (widget.hiddenComments > 0) _HeldBack(count: widget.hiddenComments, readerName: widget.readerName),
                if (widget.book.unplaced > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      widget.book.unplaced == 1
                          ? '1 comment was on a chapter no longer in the book.'
                          : '${widget.book.unplaced} comments were on chapters no longer in the book.',
                      textAlign: TextAlign.center,
                      style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _Turner(turner: t, onTurn: _go),
      ],
    );
  }
}

/// One page of the book, set as the manuscript, the active comment's passage
/// tinted where it sits.
class _PageView extends StatelessWidget {
  const _PageView({required this.page, required this.active});
  final BookPage page;
  final PlacedBetaComment? active;

  static final TextStyle _text = DsStyle.prose(const DsStep(17, 27), color: Ds.soft);

  Widget _block(int i, PageBlock block) {
    switch (block.kind) {
      case PageBlockKind.sceneBreak:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text('*   *   *', textAlign: TextAlign.center, style: _text.copyWith(color: Ds.low)),
        );
      case PageBlockKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 14),
          child: Text(
            block.text,
            textAlign: TextAlign.center,
            style: DsStyle.prose(const DsStep(22, 28), color: Ds.hi),
          ),
        );
      case PageBlockKind.paragraph:
        final at = active?.at;
        final spans = <TextSpan>[];
        if (at != null && at.block == i) {
          final len = block.text.length;
          final from = at.from.clamp(0, len);
          final to = at.to.clamp(from, len);
          spans.addAll([
            TextSpan(text: block.text.substring(0, from)),
            TextSpan(
              text: block.text.substring(from, to),
              style: TextStyle(color: Ds.hi, backgroundColor: Ds.accent.withValues(alpha: 0.24)),
            ),
            TextSpan(text: block.text.substring(to)),
          ]);
        } else {
          spans.add(TextSpan(text: block.text));
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(
            TextSpan(
              style: _text,
              // A paragraph carried over from the page before is not indented.
              children: [if (!block.continued) const TextSpan(text: ' '), ...spans],
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => ReportCard(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              chapterLabel(page.chapter).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DsStyle.eyebrow(),
            ),
            const SizedBox(height: 14),
            for (final (i, block) in page.blocks.indexed) _block(i, block),
          ],
        ),
      );
}

/// A comment on the open page; the active one is outlined in the accent.
class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.active, required this.onPressed});
  final PlacedBetaComment comment;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: active ? Ds.surf : Ds.panel,
            border: Border.all(color: active ? Ds.accent.withValues(alpha: 0.55) : (pressed ? Ds.edgeHi : Ds.edge)),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReactionChip(reaction: comment.reaction),
              if (comment.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(comment.note, style: DsStyle.prose(DsText.body, color: active ? Ds.hi : Ds.mid)),
              ],
            ],
          ),
        ),
      );
}

/// Under the comments a preview placed: how many more there are, and the
/// padlock that says which plan shows them. The phone never sells.
class _HeldBack extends ConsumerWidget {
  const _HeldBack({required this.count, required this.readerName});
  final int count;
  final String readerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(capabilityProvider(fullReportsCapability));
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ReportCard(
        child: Column(
          children: [
            Text(
              count == 1
                  ? '$readerName left 1 more comment, kept for you.'
                  : '$readerName left $count more comments, kept for you.',
              textAlign: TextAlign.center,
              style: DsStyle.ui(DsText.body, color: Ds.mid),
            ),
            const SizedBox(height: 14),
            GkButton(
              label: 'See every comment',
              onPressed: () => explainLock(context, gate, fullReportsLabel),
              leading: Icon(LucideIcons.lock, size: 14, color: Ds.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bottom bar: a comment at a time, then a page at a time.
class _Turner extends StatelessWidget {
  const _Turner({required this.turner, required this.onTurn});
  final PageTurner turner;
  final void Function(PageTurner?) onTurn;

  @override
  Widget build(BuildContext context) {
    final t = turner;
    final count = t.commentCount;
    final commentLabel = switch ((count, t.active)) {
      (0, _) => 'No comments',
      (_, final int a) => 'Comment ${a + 1} of $count',
      _ => count == 1 ? '1 comment' : '$count comments',
    };
    return Container(
      decoration: BoxDecoration(
        color: Ds.panel,
        border: Border(top: BorderSide(color: Ds.edge)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Row(
            label: commentLabel,
            color: t.active != null ? Ds.accent : Ds.mid,
            prev: t.prevComment,
            next: t.nextComment,
            prevLabel: 'Previous comment',
            nextLabel: 'Next comment',
            onTurn: onTurn,
          ),
          _Row(
            label: 'Page ${t.page + 1} of ${t.pageCount}',
            color: Ds.soft,
            prev: t.prevPage,
            next: t.nextPage,
            prevLabel: 'Previous page',
            nextLabel: 'Next page',
            onTurn: onTurn,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.color,
    required this.prev,
    required this.next,
    required this.prevLabel,
    required this.nextLabel,
    required this.onTurn,
  });
  final String label;
  final Color color;
  final PageTurner? prev;
  final PageTurner? next;
  final String prevLabel;
  final String nextLabel;
  final void Function(PageTurner?) onTurn;

  Widget _arrow(IconData icon, PageTurner? to, String semantic) => Press(
        onPressed: to == null ? null : () => onTurn(to),
        semanticLabel: semantic,
        builder: (context, pressed) => SizedBox(
          width: DsGeom.row,
          height: DsGeom.row,
          child: Icon(icon, size: 20, color: to == null ? Ds.faint : (pressed ? Ds.hi : Ds.soft)),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _arrow(LucideIcons.chevronLeft, prev, prevLabel),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: DsStyle.ui(DsText.ui, color: color).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          _arrow(LucideIcons.chevronRight, next, nextLabel),
        ],
      );
}
