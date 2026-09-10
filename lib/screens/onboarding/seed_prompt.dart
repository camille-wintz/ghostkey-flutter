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
// to summarise the thing they cannot start is the wrong first move.

String seedPrompt() => [
      'I want to write a book. Please help me refine my idea and work out what genre it really is.',
      "I don't know whether to start by plotting or to jump straight into writing — help me pick whichever suits me, and say why.",
      'If we decide to plot, help me choose a structure, work out the beats with me, and organise them into chapters.',
    ].join('\n\n');

/// What a book is called before anyone has decided. The guided branch makes one
/// of these: renaming is one field in project settings, and a title is
/// something the conversation arrives at.
const String defaultTitle = 'Untitled book';
