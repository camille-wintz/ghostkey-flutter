import 'package:flutter/widgets.dart';

import '../../server/dto/chat.dart';
import 'attachment_chip.dart';

/// The chips above the composer, each removable, until the message is sent.
class AttachmentTray extends StatelessWidget {
  const AttachmentTray({super.key, required this.attachments, required this.onRemove});
  final List<ChatAttachment> attachments;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final a in attachments)
            AttachmentChip(key: ValueKey(a.id), attachment: a, onRemove: () => onRemove(a.id)),
        ],
      ),
    );
  }
}
