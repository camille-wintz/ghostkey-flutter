import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/dates.dart';
import '../../ds/tokens.dart';
import '../../server/dto/work_plan.dart';
import '../../ui/press.dart';

/// One work plan in the drawer: its name, when it last moved, and how many
/// conversations work under it. Tap starts a new one under it; long-press to
/// open, rename or delete.
class PlanRow extends StatelessWidget {
  const PlanRow({
    super.key,
    required this.plan,
    required this.active,
    required this.onPressed,
    required this.onLongPress,
  });

  final WorkPlanSummary plan;

  /// The open conversation works under this plan.
  final bool active;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  String get _meta {
    final count = plan.sessions.length;
    final chats = count == 0 ? 'no chats yet' : '$count ${count == 1 ? 'chat' : 'chats'}';
    return '${formatRelativeTime(plan.updatedAt)} · $chats';
  }

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        onLongPress: onLongPress,
        semanticLabel: 'New chat under ${plan.name}',
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : const Color(0x00000000),
            border: Border(left: BorderSide(color: active ? Ds.accent : const Color(0x00000000), width: 2.5)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.listChecks, size: 15, color: active ? Ds.accent : Ds.mid),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.name.isEmpty ? 'Untitled plan' : plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(DsText.ui, color: active ? Ds.accent : Ds.soft, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(_meta, style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
                  ],
                ),
              ),
              Icon(LucideIcons.plus, size: 15, color: Ds.faint),
            ],
          ),
        ),
      );
}
