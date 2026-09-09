import 'package:flutter/widgets.dart';

import '../../ds/tokens.dart';
import '../notices.dart';

/// One line the writer must read: amber for a pause they can undo, the
/// destructive hue for words that are already gone.
class DockNoticeView extends StatelessWidget {
  const DockNoticeView(this.notice, {super.key});
  final DockNotice notice;

  @override
  Widget build(BuildContext context) {
    final error = notice.kind == NoticeKind.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DsGeom.radius),
          border: Border.all(color: error ? Ds.destructive : Ds.attention),
          color: error ? const Color.fromRGBO(212, 83, 106, 0.12) : Ds.attentionMix(12),
        ),
        child: Text(notice.text, style: DsStyle.ui(DsText.ui, color: Ds.soft)),
      ),
    );
  }
}
