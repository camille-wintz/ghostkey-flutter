import '../server/dto/billing.dart';
import '../server/dto/wisp.dart';

// What each Wisp run is gated on and counted against. The capability ids and
// quota features are the server's (`billing/access/policy.ts`,
// `billing/quota/policy.ts`); the desk reads the same ones.

const String analysisCapability = 'wisp.book_analysis';
const String outlineCapability = 'phantom.reverse_outline';
const String continuityCapability = 'phantom.continuity';

const String outlineQuotaFeature = 'reverse_outline';
const String continuityQuotaFeature = 'continuity';
const String lineEditQuotaFeature = 'edit_pass';

/// The counter an analysis spends. On free the three share `book_analysis`,
/// which only free's snapshot carries; everywhere else each counts on its own.
/// Read off the snapshot, so the server's table stays the one that decides.
String analysisQuotaFeature(QuotaSnapshot? snapshot, AnalysisId analysis) =>
    snapshot?.feature('book_analysis') != null ? 'book_analysis' : '${analysis.wire}_analysis';
