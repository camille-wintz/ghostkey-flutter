import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/dates.dart';
import '../../ds/tokens.dart';
import '../../server/dto/chat.dart';
import 'pulse.dart';
import '../../ui/press.dart';

/// One saved chat in the drawer: title and when it last moved — or, while
/// the server is answering in it, that it is. Long-press for rename /
/// delete. [nested] sets it in under the work plan it belongs to.
class SessionRow extends StatelessWidget {
  const SessionRow({
    super.key,
    required this.session,
    required this.active,
    required this.onPressed,
    required this.onLongPress,
    this.nested = false,
  });

  final ChatSessionSummary session;
  final bool active;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;
  final bool nested;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        onLongPress: onLongPress,
        semanticLabel: session.title,
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          constraints: const BoxConstraints(minHeight: 46),
          padding: EdgeInsets.only(left: nested ? 36 : 12, right: 12, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: active ? Ds.accentMix(10) : (pressed ? Ds.veil : const Color(0x00000000)),
            border: Border(left: BorderSide(color: active ? Ds.accent : const Color(0x00000000), width: 2.5)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.messageSquare, size: 15, color: active ? Ds.accent : Ds.faint),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      session.title.isEmpty ? 'Untitled chat' : session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(
                        DsText.ui,
                        color: active ? Ds.accent : Ds.soft,
                        weight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    switch (session.status) {
                      ConversationStatus.idle =>
                        Text(formatRelativeTime(session.updatedAt), style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
                      ConversationStatus.running || ConversationStatus.queued => Pulse(
                          active: true,
                          child: Text('Answering…', style: DsStyle.ui(DsText.eyebrow, color: Ds.accent)),
                        ),
                    },
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
