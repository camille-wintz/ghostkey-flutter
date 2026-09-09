import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import 'poltergeist_tabs.dart';

/// The ledger's menu, laid along the foot of the phone: four rows' worth of
/// destinations, the open one in the accent, the task count beside Tasks.
class PoltergeistTabBar extends StatelessWidget {
  const PoltergeistTabBar({super.key, required this.current, required this.openTasks, required this.onOpen});
  final PoltergeistTab current;
  final int openTasks;
  final void Function(PoltergeistTab tab) onOpen;

  @override
  Widget build(BuildContext context) => Container(
        height: 58,
        decoration: BoxDecoration(color: Ds.panel, border: Border(top: BorderSide(color: Ds.edge))),
        child: Row(
          children: [
            for (final tab in PoltergeistTab.values)
              Expanded(
                child: _TabItem(
                  tab: tab,
                  active: tab == current,
                  badge: tab == PoltergeistTab.tasks && openTasks > 0 ? openTasks : null,
                  onPressed: () => onOpen(tab),
                ),
              ),
          ],
        ),
      );
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.active, required this.badge, required this.onPressed});
  final PoltergeistTab tab;
  final bool active;
  final int? badge;
  final VoidCallback onPressed;

  IconData get _icon => switch (tab) {
        PoltergeistTab.dashboard => LucideIcons.layoutDashboard,
        PoltergeistTab.words => LucideIcons.penLine,
        PoltergeistTab.tasks => LucideIcons.listChecks,
        PoltergeistTab.plan => LucideIcons.bookOpen,
      };

  String get _label => switch (tab) {
        PoltergeistTab.dashboard => 'Dashboard',
        PoltergeistTab.words => 'Words',
        PoltergeistTab.tasks => 'Tasks',
        PoltergeistTab.plan => 'Plan',
      };

  @override
  Widget build(BuildContext context) {
    final ink = active ? Ds.accent : Ds.low;
    return Press(
      onPressed: onPressed,
      semanticLabel: badge != null ? '$_label, $badge open' : _label,
      builder: (context, pressed) => Container(
        color: pressed ? Ds.veil : const Color(0x00000000),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon, size: 17, color: active ? Ds.accent : Ds.faint),
                if (badge != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    '$badge',
                    style: DsStyle.ui(DsText.eyebrow, color: Ds.accent, weight: FontWeight.w600),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(
              _label.toUpperCase(),
              style: DsStyle.ui(DsText.eyebrow, color: ink, weight: FontWeight.w600, tracking: DsTracking.pill),
            ),
          ],
        ),
      ),
    );
  }
}
