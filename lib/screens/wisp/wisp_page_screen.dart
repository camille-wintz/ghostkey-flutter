import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import '../../server/providers.dart';
import '../../ui/room_subtitle.dart';
import '../../ui/room_title_bar.dart';
import '../project/project_root.dart';
import 'analysis_page.dart';
import 'continuity_page.dart';
import 'line_editing_page.dart';
import 'reverse_outline_page.dart';
import '../../wisp/pages.dart';

/// One Wisp task as a page pushed over the room's list: its name in the bar,
/// the book under it, and back to the list.
class WispPageScreen extends ConsumerWidget {
  const WispPageScreen({super.key, required this.page});
  final WispPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookTitle = ref.watch(projectProvider(ProjectScope.of(context))).value?.project.displayTitle;
    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RoomTitleBar(
              title: page.label,
              subtitle: bookTitle == null ? null : RoomSubtitle(bookTitle),
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: switch (page) {
                WispPage.lineEditing => const LineEditingPage(),
                WispPage.theme => const AnalysisPage(analysis: AnalysisId.theme),
                WispPage.pacing => const AnalysisPage(analysis: AnalysisId.pacing),
                WispPage.genre => const AnalysisPage(analysis: AnalysisId.genre),
                WispPage.continuity => const ContinuityPage(),
                WispPage.reverseOutline => const ReverseOutlinePage(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
