import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../chat/quota_feature.dart';
import '../../core/dates.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../ui/button.dart';
import '../../ui/job_running.dart';
import '../../ui/page_notice.dart';
import '../../ui/room_subtitle.dart';
import '../../ui/room_title_bar.dart';
import '../../wisp/access.dart';
import '../../wisp/providers.dart';
import '../../wisp/wisp_run.dart';
import 'beta_book_screen.dart';
import 'beta_letter.dart';
import 'beta_read_start.dart';
import 'reader_portrait.dart';
import 'report_preview.dart';
import 'run_again.dart';
import 'wisp_page_loading.dart';

/// One beta reader's letter, pushed over the readers: the letter once it is
/// kept, with a fresh read under it — padlocked below `wisp.full_reports`.
/// A refused run is answered by the reader's card underneath.
class BetaLetterScreen extends ConsumerWidget {
  const BetaLetterScreen({super.key, required this.projectId, required this.reader});
  final String projectId;
  final ReaderCard reader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readKey = (projectId: projectId, analysis: reader.analysis);
    final read = ref.watch(analysisProvider(readKey));
    // Read beside the letter for the comment count, and so the book is
    // already here when it is opened.
    final pages = ref.watch(betaReaderPagesProvider((projectId: projectId, reader: reader.id)));
    final run = ref.watch(wispRunProvider(analysisRunKey(projectId, reader.analysis)));
    final gate = ref.watch(capabilityProvider(analysisCapability));
    final fullGate = ref.watch(capabilityProvider(fullReportsCapability));
    final tooShort = tooShortForWholeBook(ref.watch(projectProvider(projectId)).value);
    final quota = quotaLine(ref.watch(quotaProvider).value?.lineFor(betaReadQuotaFeature));

    void start({required bool again}) => startBetaRead(context, ref, projectId, reader, again: again);

    final Widget body;
    if (run.running) {
      body = JobRunning(progress: run.progress, starting: '${reader.name} is reading');
    } else if (read.hasError && !read.hasValue) {
      body = PageNotice("The letter wouldn't load: ${messageFor(read.error)}", error: true);
    } else if (!read.hasValue) {
      body = const WispPageLoading('Opening the letter…');
    } else if (read.value?.report case final r?) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Read ${formatShortDate(r.generatedAt)} · ${r.chapterCount} chapters',
            style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
          ),
          const SizedBox(height: 14),
          BetaLetter(
            report: r,
            readerName: reader.name,
            commentCount: switch (pages.value) {
              BetaReaderPages(book: final book?, :final hiddenComments) => book.comments.length + hiddenComments,
              _ => read.value?.preview == null ? r.comments.length : null,
            },
            onReadBook: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BetaBookScreen(projectId: projectId, reader: reader),
              ),
            ),
          ),
          if (read.value?.preview case final cut?) ReportPreview(cut: cut, subject: 'letter'),
          RunAgain(
            label: 'Ask for a fresh read',
            onRun: () => start(again: true),
            locked: !gate.granted || !fullGate.granted,
            disabled: tooShort,
            quota: quota,
          ),
        ],
      );
    } else {
      // The catalogue said a letter was kept, and it is gone (or from an
      // older format): offer the read again rather than an empty page.
      body = Column(
        children: [
          PageNotice("There's no letter from ${reader.name} for this book yet."),
          GkButton(
            label: 'Ask ${reader.name} to read',
            onPressed: () => start(again: false),
            disabled: tooShort,
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RoomTitleBar(
              title: reader.name,
              subtitle: const RoomSubtitle('Beta readers'),
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: RefreshIndicator(
                color: Ds.accent,
                backgroundColor: Ds.panel,
                onRefresh: () => ref.refresh(analysisProvider(readKey).future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                  children: [
                    Row(
                      children: [
                        ReaderPortrait(reader: reader, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'A letter from ${reader.name}',
                            style: DsStyle.prose(const DsStep(20, 26), color: Ds.hi),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (run.error case final error? when !run.running && run.denial == null) PageNotice(error, error: true),
                    body,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
