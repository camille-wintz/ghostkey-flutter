// What Mara's actions are gated on and counted against. The capability ids
// and quota features are the server's (`billing/access/policy.ts`,
// `billing/quota/policy.ts`); the desk reads the same ones. They keep the
// `mara.` prefix whatever room they sit in: a capability id is a wire name.

/// Planning chapters from a plan — which happens in the chat.
const String chapterPlanCapability = 'mara.chapter_breakdown';

/// Writing the outline from the book.
const String outlineSketchCapability = 'mara.outline_sketch';

/// Filling a board from the book spends the book map's allowance.
const String boardFillQuotaFeature = 'book_map';
