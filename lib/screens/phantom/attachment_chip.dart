import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../server/dto/chat.dart';
import '../../ui/press.dart';

/// "3 204 words" / "empty" / nothing when the length is unknown.
String? lengthLabel(ChatAttachment a) {
  final words = switch (a) {
    ChapterAttachment(:final words) => words,
    PasteAttachment(:final words) => words,
    FileAttachment(:final words) => words,
  };
  if (words == null) return null;
  if (words == 0) return 'empty';
  return '${formatWords(words)} word${words == 1 ? '' : 's'}';
}

/// Title · length. A paste unfolds on tap to show what was lifted out of the
/// composer; a chapter does not — its body is in the manuscript, not here.
class AttachmentChip extends StatefulWidget {
  const AttachmentChip({super.key, required this.attachment, this.onRemove});
  final ChatAttachment attachment;
  final VoidCallback? onRemove;

  @override
  State<AttachmentChip> createState() => _AttachmentChipState();
}

class _AttachmentChipState extends State<AttachmentChip> {
  bool _unfolded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final paste = a is PasteAttachment;
    final length = lengthLabel(a);
    final onRemove = widget.onRemove;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Press(
          onPressed: paste ? () => setState(() => _unfolded = !_unfolded) : null,
          builder: (context, pressed) => Container(
            height: 30,
            padding: EdgeInsets.only(left: 9, right: onRemove != null ? 4 : 9),
            decoration: BoxDecoration(
              color: pressed ? Ds.raise : Ds.surf,
              border: Border.all(color: Ds.edge),
              borderRadius: BorderRadius.circular(DsGeom.radius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  switch (a) {
                    PasteAttachment() => LucideIcons.clipboard,
                    FileAttachment() => LucideIcons.fileUp,
                    ChapterAttachment() => LucideIcons.fileText,
                  },
                  size: 13,
                  color: Ds.mid,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsStyle.ui(DsText.ui, color: Ds.soft),
                  ),
                ),
                if (length != null) ...[
                  const SizedBox(width: 6),
                  Text(length, style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
                ],
                if (onRemove != null) ...[
                  const SizedBox(width: 4),
                  Press(
                    onPressed: onRemove,
                    semanticLabel: 'Remove attachment',
                    hitSlop: 4,
                    builder: (context, pressed) => Icon(LucideIcons.x, size: 15, color: pressed ? Ds.hi : Ds.mid),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (paste && _unfolded)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              a.text,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: DsStyle.ui(DsText.ui, color: Ds.mid),
            ),
          ),
      ],
    );
  }
}
