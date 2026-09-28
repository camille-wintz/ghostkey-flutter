import '../server/dto/projects.dart';
import '../server/dto/wisp.dart';

// What each Wisp run is gated on and counted against. The capability ids and
// quota features are the server's (`billing/access/policy.ts`,
// `billing/quota/policy.ts`); the desk reads the same ones.

const String analysisCapability = 'wisp.book_analysis';
const String outlineCapability = 'phantom.reverse_outline';
const String continuityCapability = 'phantom.continuity';

/// Below it, the reports read back as previews and each is made once: a
/// forced re-read is refused (`ghostkey-server` `lib/wisp/preview.ts`).
const String fullReportsCapability = 'wisp.full_reports';
const String fullReportsLabel = 'Whole Wisp reports';

const String outlineQuotaFeature = 'reverse_outline';
const String continuityQuotaFeature = 'continuity';
const String lineEditQuotaFeature = 'edit_pass';

/// The counter an analysis spends, each on its own. Free carries none of
/// them: its analyses are uncounted previews since 2026-09-28.
String analysisQuotaFeature(AnalysisId analysis) => '${analysis.wire}_analysis';

/// The floor under a pass that reads the whole book: the reverse outline,
/// continuity and the three analyses. The server refuses them under it
/// (`manuscript_too_short`, `ghostkey-server` `lib/jobs/registry.ts`) and the
/// desk withholds them at the same number (`shared/manuscriptSize.ts`).
const int wholeBookMinWords = 500;

const String wholeBookTooShort = 'These read the whole book, so they open at 500 words.';

/// The book's length, or null while any chapter's count is unknown — a gate
/// must never read "not known here" as an empty book.
int? manuscriptWords(List<ChaptersListEntry> chapters) {
  var total = 0;
  for (final chapter in chaptersInTree(chapters)) {
    final words = chapter.wordCount;
    if (words == null) return null;
    total += words;
  }
  return total;
}

/// Whether the whole-book passes are withheld: known, and under the floor.
bool tooShortForWholeBook(ProjectFull? project) {
  final words = project == null ? null : manuscriptWords(project.chapters);
  return words != null && words < wholeBookMinWords;
}
