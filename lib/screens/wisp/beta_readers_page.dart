import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/quota_feature.dart';
import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/dto/wisp.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../ui/page_notice.dart';
import '../../wisp/access.dart';
import '../../wisp/providers.dart';
import '../project/project_root.dart';
import 'beta_letter_screen.dart';
import 'reader_card_tile.dart';
import 'wisp_page_loading.dart';

/// Wisp's beta readers: every cat the server lists, each with their shelf and
/// their state. A letter opens as a page of its own.
class BetaReadersPage extends ConsumerWidget {
  const BetaReadersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final project = ref.watch(projectProvider(projectId)).value;
    final hasChapters = project != null && chaptersInTree(project.chapters).isNotEmpty;
    final tooShort = tooShortForWholeBook(project);
    final readers = ref.watch(betaReadersProvider(projectId));
    final quota = quotaLine(ref.watch(quotaProvider).value?.lineFor(betaReadQuotaFeature));

    void open(ReaderCard reader) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BetaLetterScreen(projectId: projectId, reader: reader),
          ),
        );

    final List<Widget> body;
    if (project != null && !hasChapters) {
      body = [const PageNotice('The manuscript has no chapters yet. Add some in Apparition and come back to Wisp.')];
    } else if (readers.hasError && !readers.hasValue) {
      body = [PageNotice("The readers wouldn't load: ${messageFor(readers.error)}", error: true)];
    } else if (readers.value case final list?) {
      body = [
        Text(
          'Each cat reads the whole book, then writes you a letter in their own voice.',
          style: DsStyle.prose(DsText.body, color: Ds.mid),
        ),
        const SizedBox(height: 16),
        if (tooShort) const PageNotice(wholeBookTooShort),
        for (final reader in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ReaderCardTile(
              projectId: projectId,
              reader: reader,
              onOpen: () => open(reader),
              disabled: project == null || tooShort,
            ),
          ),
        if (quota != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(quota, textAlign: TextAlign.center, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
          ),
      ];
    } else {
      body = [const WispPageLoading('Finding your readers…')];
    }

    return RefreshIndicator(
      color: Ds.accent,
      backgroundColor: Ds.panel,
      onRefresh: () => ref.refresh(betaReadersProvider(projectId).future),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 40), children: body),
    );
  }
}
