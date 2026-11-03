// A chapter as the chat's answers name it (`chapter:<id>`, the server's
// lib/chat/chapterRefs.ts). The server shows a finished answer under its current
// names; an answer still being written is as the model wrote it, and is named here.

final RegExp _ref = RegExp(r'\[[^\]\n]*\]\(chapter:\{?([0-9a-f-]{36})\}?\)|`?\bchapter:\{?([0-9a-f-]{36})\}?`?', caseSensitive: false);

/// A reference the stream has only got partway through.
final RegExp _partial = RegExp(r'`?\bchapter:\{?[0-9a-f-]{0,35}$|\[[^\]\n]*\]\(chapter:[^)\n]*$', caseSensitive: false);

const String chapterScheme = 'chapter:';

/// Text still arriving, with its references as links to chapters by [names]
/// (document id to the name it reads as).
String linkChapterRefs(String text, Map<String, String> names) =>
    text.replaceFirst(_partial, '').replaceAllMapped(_ref, (m) {
      final id = (m[1] ?? m[2]!).toLowerCase();
      final name = names[id];
      return name == null ? '' : '[${name.replaceAll(RegExp(r'\.md$', caseSensitive: false), '')}]($chapterScheme$id)';
    });
