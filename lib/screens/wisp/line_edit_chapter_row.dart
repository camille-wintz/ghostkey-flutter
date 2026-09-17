import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../server/dto/jobs.dart';
import '../../server/dto/projects.dart';
import '../../ui/button.dart';
import '../../ui/press.dart';
import 'line_editing_page.dart';

/// One chapter and its line edit, read off the shared job feed — a pass
/// started on the desk shows here, and one started here shows there. The
/// name opens the chapter's page; the button starts a pass, or becomes
/// Review once one has notes waiting.
class LineEditChapterRow extends StatelessWidget {
  const LineEditChapterRow({
    super.key,
    required this.index,
    required this.chapter,
    required this.pass,
    required this.divider,
    required this.onOpen,
    required this.onLineEdit,
  });

  final int index;
  final DocumentSummary chapter;
  final JobSnapshot? pass;
  final bool divider;
  final VoidCallback onOpen;
  final VoidCallback onLineEdit;

  @override
  Widget build(BuildContext context) {
    final running = pass?.isRunning ?? false;
    final notes = waitingNotes(pass);
    final words = chapter.wordCount;
    final status = running
        ? 'Line edit running…'
        : notes != null
            ? '$notes ${notes == 1 ? 'note' : 'notes'} waiting'
            : words != null
                ? '${formatWords(words)} words'
                : '';

    return Container(
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: Ds.edge)) : null),
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      child: Row(
        children: [
          Expanded(
            child: Press(
              onPressed: onOpen,
              semanticLabel: '${chapter.label}, $status',
              builder: (context, pressed) => AnimatedContainer(
                duration: DsMotion.duration,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: pressed ? Ds.veil : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(DsGeom.radius),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 26, child: Text('${index + 1}', style: DsStyle.ui(DsText.ui, color: Ds.low))),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chapter.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsStyle.prose(DsText.body, color: Ds.hi),
                          ),
                          if (status.isNotEmpty)
                            Text(
                              status,
                              style: DsStyle.ui(DsText.eyebrow, color: notes != null ? Ds.accent : Ds.low),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (notes != null)
            GkButton(
              label: 'Review',
              variant: ButtonVariant.outline,
              onPressed: onOpen,
              leading: Icon(LucideIcons.chevronRight, size: 14, color: Ds.mid),
            )
          else
            GkButton(
              label: 'Line edit',
              variant: ButtonVariant.outline,
              busy: running,
              disabled: running,
              onPressed: onLineEdit,
              leading: Icon(LucideIcons.penLine, size: 14, color: Ds.mid),
            ),
        ],
      ),
    );
  }
}
