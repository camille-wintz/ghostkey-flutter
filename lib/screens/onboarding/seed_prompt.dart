// The guided branch's first message — the same words the desk sends
// (ghost-key src/launcher/onboarding/seedPrompt.ts). Edit both together.
//
// In the author's voice, not written as instructions to a model: it is the
// first line of their own transcript and they can scroll back to it. It names
// no room, because the chat has read_guide and a prompt naming menus would be
// a second copy of the handbook.

/// One line of a first message, not a synopsis — the conversation is where the
/// rest comes out.
const int _ideaMax = 600;

String seedPrompt(String idea) {
  final said = idea.trim();
  final clipped = said.length > _ideaMax ? said.substring(0, _ideaMax) : said;
  return [
    'I want to write a book. Please help me refine my idea and work out what genre it really is.',
    "I don't know whether to start by plotting or to jump straight into writing — help me pick whichever suits me, and say why.",
    'If we decide to plot, help me choose a structure, work out the beats with me, and organise them into chapters.',
    if (clipped.isNotEmpty) "Here's what I have so far: $clipped",
  ].join('\n\n');
}

/// What the typed idea names the book. A premise is a sentence and a shelf
/// spine is not, so it is cut at a word boundary with trailing punctuation
/// taken off — the question says it names the book, and "…in daylight," on the
/// shelf reads as a mistake.
const int _titleMax = 60;
const String defaultTitle = 'Untitled book';

String titleFromIdea(String idea) {
  final said = idea.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (said.isEmpty) return defaultTitle;
  if (said.length <= _titleMax) return said;
  final cut = said.substring(0, _titleMax);
  final lastSpace = cut.lastIndexOf(' ');
  final clipped = lastSpace > _titleMax ~/ 2 ? cut.substring(0, lastSpace) : cut;
  return clipped.replaceAll(RegExp(r'[\s,;:.—-]+$'), '');
}
