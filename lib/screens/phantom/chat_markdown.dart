import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../ds/tokens.dart';

// THE markdown renderer for assistant prose: package:markdown does the
// parsing, this file owns the AST → span/widget mapping so it speaks the
// design system's faces. Nothing else in the app parses markdown for
// display. Re-parsed on every build — a streaming answer is a few KB, and
// the parse is far cheaper than the layout that follows it.

final md.Document _document = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored, encodeHtml: false);

const Set<String> _blockTags = {'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'blockquote', 'pre', 'hr', 'table'};

class ChatMarkdown extends StatefulWidget {
  const ChatMarkdown(this.text, {super.key});
  final String text;

  @override
  State<ChatMarkdown> createState() => _ChatMarkdownState();
}

class _ChatMarkdownState extends State<ChatMarkdown> {
  /// Link recognizers made by the last build. Rebuilt with the tree, so the
  /// previous set is released each time.
  final List<TapGestureRecognizer> _recognizers = [];

  void _releaseRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _releaseRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _releaseRecognizers();
    final List<md.Node> nodes;
    try {
      nodes = _document.parse(widget.text);
    } catch (_) {
      return Text(widget.text, style: _prose);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: _blocks(nodes, tight: false),
    );
  }

  // ── Block level ─────────────────────────────────────────────────────────

  List<Widget> _blocks(List<md.Node> nodes, {required bool tight}) {
    final visible = nodes.where((n) => n is md.Element || n.textContent.trim().isNotEmpty).toList();
    return [
      for (var i = 0; i < visible.length; i++)
        _block(visible[i], first: i == 0, last: i == visible.length - 1, tight: tight),
    ];
  }

  Widget _block(md.Node node, {required bool first, required bool last, required bool tight}) {
    final gap = last || tight ? 0.0 : 10.0;
    if (node is! md.Element) return _paragraph([node], gap: gap);
    final children = node.children ?? const <md.Node>[];
    return switch (node.tag) {
      'p' => _paragraph(children, gap: gap),
      'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6' => Padding(
          padding: EdgeInsets.only(top: first ? 0 : 6, bottom: last ? 0 : 8),
          child: Text.rich(TextSpan(children: _inlines(children, _heading(node.tag))), style: _heading(node.tag)),
        ),
      'ul' || 'ol' => _list(node, gap: gap),
      'blockquote' => Container(
          margin: EdgeInsets.only(bottom: gap),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: Ds.accentMix(55), width: 2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: _blocks(children, tight: false),
          ),
        ),
      'pre' => Container(
          margin: EdgeInsets.only(bottom: gap),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Ds.raise, borderRadius: BorderRadius.circular(DsGeom.radius)),
          child: Text(node.textContent.trimRight(), style: _mono),
        ),
      'hr' => Container(height: 1, color: Ds.edge, margin: EdgeInsets.symmetric(vertical: last ? 0 : 12)),
      // Tables, raw html — shown as their text rather than lost.
      'table' => _table(node, gap: gap),
      _ => _paragraph(children.isEmpty ? [node] : children, gap: gap),
    };
  }

  Widget _paragraph(List<md.Node> inlines, {required double gap}) => Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Text.rich(TextSpan(children: _inlines(inlines, _prose)), style: _prose),
      );

  Widget _list(md.Element list, {required double gap}) {
    final ordered = list.tag == 'ol';
    final start = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    final items = (list.children ?? const <md.Node>[]).whereType<md.Element>().where((e) => e.tag == 'li').toList();
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 22),
                    child: Text(ordered ? '${start + i}.' : '•', textAlign: TextAlign.right, style: _marker),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _listItem(items[i])),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// A tight item's body is inline nodes; a loose item's is paragraphs and
  /// nested lists.
  Widget _listItem(md.Element item) {
    final children = item.children ?? const <md.Node>[];
    final loose = children.any((c) => c is md.Element && _blockTags.contains(c.tag));
    if (!loose) return _paragraph(children, gap: 0);
    // A tight item that carries a nested list arrives as inline nodes
    // followed by the list; split so the text stays a paragraph.
    final widgets = <Widget>[];
    var run = <md.Node>[];
    void flush() {
      if (run.isEmpty) return;
      widgets.add(_paragraph(run, gap: 4));
      run = [];
    }

    for (final c in children) {
      if (c is md.Element && _blockTags.contains(c.tag)) {
        flush();
        widgets.add(_block(c, first: widgets.isEmpty, last: false, tight: true));
      } else {
        run.add(c);
      }
    }
    flush();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: widgets);
  }

  Widget _table(md.Element table, {required double gap}) {
    final rows = <String>[];
    void collect(md.Node n) {
      if (n is! md.Element) return;
      if (n.tag == 'tr') {
        final cells = (n.children ?? const <md.Node>[]).map((c) => c.textContent.trim()).where((t) => t.isNotEmpty);
        rows.add(cells.join('  ·  '));
        return;
      }
      for (final c in n.children ?? const <md.Node>[]) {
        collect(c);
      }
    }

    collect(table);
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [for (final r in rows) Text(r, style: _prose)],
      ),
    );
  }

  // ── Inline level ────────────────────────────────────────────────────────

  List<InlineSpan> _inlines(List<md.Node> nodes, TextStyle base) => [for (final n in nodes) _inline(n, base)];

  InlineSpan _inline(md.Node node, TextStyle base) {
    if (node is md.Text) return TextSpan(text: _softBreaks(node.text));
    if (node is! md.Element) return TextSpan(text: node.textContent);
    final children = node.children ?? const <md.Node>[];
    switch (node.tag) {
      case 'strong':
        final style = base.copyWith(fontWeight: FontWeight.w600, color: Ds.hi);
        return TextSpan(style: style, children: _inlines(children, style));
      case 'em':
        final style = base.copyWith(fontStyle: FontStyle.italic);
        return TextSpan(style: style, children: _inlines(children, style));
      case 'del':
        final style = base.copyWith(decoration: TextDecoration.lineThrough);
        return TextSpan(style: style, children: _inlines(children, style));
      case 'code':
        return TextSpan(text: node.textContent, style: _mono.copyWith(backgroundColor: Ds.raise));
      case 'a':
        final href = node.attributes['href'];
        final recognizer = href == null ? null : (TapGestureRecognizer()..onTap = () => _open(href));
        if (recognizer != null) _recognizers.add(recognizer);
        final style = base.copyWith(color: Ds.accent, decoration: TextDecoration.underline, decorationColor: Ds.accent);
        return TextSpan(style: style, recognizer: recognizer, children: _inlines(children, style));
      case 'br':
        return const TextSpan(text: '\n');
      case 'img':
        return TextSpan(text: node.attributes['alt'] ?? '');
      default:
        return TextSpan(children: _inlines(children, base));
    }
  }

  /// A line break inside a paragraph is a soft break: a space when drawn,
  /// as every markdown renderer draws it.
  String _softBreaks(String text) => text.replaceAll('\n', ' ');

  static void _open(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  }

  // ── Faces ───────────────────────────────────────────────────────────────

  static final TextStyle _prose = DsStyle.prose(DsText.prose, color: Ds.ink);
  static final TextStyle _marker = DsStyle.prose(DsText.prose, color: Ds.mid);
  static final TextStyle _mono = TextStyle(
    fontFamily: DsFonts.mono,
    fontSize: DsText.ui.size,
    height: DsText.body.height,
    color: Ds.soft,
  );

  static TextStyle _heading(String tag) => switch (tag) {
        'h1' => DsStyle.prose(DsText.title, weight: FontWeight.w600),
        'h2' => DsStyle.prose(DsText.prose, weight: FontWeight.w600),
        _ => DsStyle.ui(DsText.body, color: Ds.hi, weight: FontWeight.w600),
      };
}
