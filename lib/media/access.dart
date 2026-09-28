// What drawing a picture is gated on and counted against. Both ids are the
// server's (`billing/access/policy.ts`, `billing/quota/policy.ts`), and the
// desk's `useImageDraw` asks for the same two. The capability keeps the
// `mara.` prefix of the surface it was born for: a capability id is a wire
// name.

/// Whether the plan may draw at all.
const String drawCapability = 'mara.entity_portrait';

/// Every draw spends one, wherever it was asked for.
const String drawQuotaFeature = 'image_generation';
