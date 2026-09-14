// The guided branch's first message — the same words the desk sends
// (ghost-key src/launcher/onboarding/seedPrompt.ts). Edit both together.
//
// In the author's voice, not written as instructions to a model: it is the
// first line of their own transcript and they can scroll back to it. It names
// no room, because the chat has read_guide and a prompt naming menus would be
// a second copy of the handbook.
//
// It says nothing about the book either, on purpose. The flow used to ask for
// a premise first and paste it in; that question is gone, because the point of
// this branch is that the author does not know where to start, and asking them
// to summarise the thing they cannot start is the wrong first move. So it asks
// for two questions a person can answer without having an idea yet.

String seedPrompt() => 'Ask me what made me want to write and what kind of books I love';

/// What a book is called before anyone has decided. The guided branch makes one
/// of these: renaming is one field in project settings, and a title is
/// something the conversation arrives at.
const String defaultTitle = 'Untitled book';
