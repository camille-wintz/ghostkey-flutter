import 'package:flutter/material.dart';

import '../../../core/locate_quote.dart';
import '../../../ds/tokens.dart';

/// The text a review is about, read only, on the manuscript page's type. The
/// passage under review is lit and scrolled into view whenever it moves.
///
/// Laid out a line at a time so the lit line can be scrolled to; offsets are
/// kept whole, so a range located in the raw text lands where it should.
/// Markdown markers stay in (dimmed): stripping them would move every offset.
class ReviewText extends StatefulWidget {
  const ReviewText({super.key, required this.text, this.highlight});
  final String text;
  final QuoteRange? highlight;

  @override
  State<ReviewText> createState() => _ReviewTextState();
}

class _ReviewTextState extends State<ReviewText> {
  late List<QuoteRange> _lines = _split(widget.text);
  final Map<int, GlobalKey> _keys = {};

  static List<QuoteRange> _split(String text) {
    final lines = <QuoteRange>[];
    var start = 0;
    for (var i = text.indexOf('\n'); i != -1; i = text.indexOf('\n', start)) {
      lines.add((from: start, to: i));
      start = i + 1;
    }
    lines.add((from: start, to: text.length));
    return lines;
  }

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(ReviewText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _lines = _split(widget.text);
    if (old.highlight != widget.highlight) _reveal();
  }

  void _reveal() {
    final highlight = widget.highlight;
    if (highlight == null) return;
    final line = _lines.indexWhere((l) => highlight.from <= l.to);
    if (line == -1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[line]?.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(target, alignment: 0.3, duration: DsMotion.screenIn, curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: DsFonts.manuscript,
      fontSize: DsText.prose.size,
      height: DsText.prose.height,
      color: Ds.ink,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _lines.length; i++)
            if (_lines[i].from == _lines[i].to)
              const SizedBox(height: 12)
            else
              Text.rich(
                key: _keys.putIfAbsent(i, GlobalKey.new),
                TextSpan(style: base, children: _spans(_lines[i])),
              ),
        ],
      ),
    );
  }

  List<InlineSpan> _spans(QuoteRange line) {
    final text = widget.text;
    final lit = widget.highlight;
    final cuts = <int>{line.from, line.to};
    if (lit != null) {
      if (lit.from > line.from && lit.from < line.to) cuts.add(lit.from);
      if (lit.to > line.from && lit.to < line.to) cuts.add(lit.to);
    }
    final sorted = cuts.toList()..sort();
    return [
      for (var i = 0; i + 1 < sorted.length; i++)
        ..._marked(
          text.substring(sorted[i], sorted[i + 1]),
          lit != null && sorted[i] >= lit.from && sorted[i + 1] <= lit.to,
        ),
    ];
  }

  static final RegExp _markers = RegExp(r'(\*+|^#+\s?)', multiLine: true);

  List<InlineSpan> _marked(String segment, bool lit) {
    final litStyle = TextStyle(color: Ds.hi, backgroundColor: Ds.accent.withValues(alpha: 0.24));
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _markers.allMatches(segment)) {
      if (m.start > at) spans.add(TextSpan(text: segment.substring(at, m.start), style: lit ? litStyle : null));
      spans.add(TextSpan(text: m.group(0), style: lit ? litStyle.copyWith(color: Ds.low) : TextStyle(color: Ds.faint)));
      at = m.end;
    }
    if (at < segment.length) spans.add(TextSpan(text: segment.substring(at), style: lit ? litStyle : null));
    return spans;
  }
}
