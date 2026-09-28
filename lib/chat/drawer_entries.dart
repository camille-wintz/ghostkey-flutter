import '../server/dto/chat.dart';
import '../server/dto/work_plan.dart';

// The chats drawer as a list: the work plans first, each with the
// conversations under it set in beneath, then every conversation under no
// plan. A conversation is listed once — under its plan, or loose.

sealed class DrawerEntry {
  const DrawerEntry();
}

class DrawerHeading extends DrawerEntry {
  const DrawerHeading(this.label);
  final String label;
}

class DrawerPlan extends DrawerEntry {
  const DrawerPlan(this.plan);
  final WorkPlanSummary plan;
}

class DrawerSession extends DrawerEntry {
  const DrawerSession(this.session, {this.nested = false});
  final ChatSessionSummary session;
  final bool nested;
}

/// The plans listing is the address of what sits under a plan; a row the
/// sessions listing also carries is taken from there, so a rename shows
/// wherever it landed first.
List<DrawerEntry> drawerEntries(List<WorkPlanSummary> plans, List<ChatSessionSummary> sessions) {
  if (plans.isEmpty) return [for (final s in sessions) DrawerSession(s)];
  final byId = {for (final s in sessions) s.id: s};
  final nested = {for (final p in plans) for (final s in p.sessions) s.id};
  final loose = sessions.where((s) => !nested.contains(s.id)).toList();
  return [
    const DrawerHeading('Plans'),
    for (final p in plans) ...[
      DrawerPlan(p),
      for (final ref in p.sessions)
        DrawerSession(
          byId[ref.id] ??
              ChatSessionSummary(id: ref.id, title: ref.title, version: 0, updatedAt: ref.updatedAt, workPlanId: p.id),
          nested: true,
        ),
    ],
    if (loose.isNotEmpty) ...[
      const DrawerHeading('Chats'),
      for (final s in loose) DrawerSession(s),
    ],
  ];
}
