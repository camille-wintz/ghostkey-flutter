import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/model_access.dart';
import '../../chat/models.dart';
import '../../chat/refusals.dart';
import '../../ds/tokens.dart';
import '../../server/providers.dart';
import '../../ui/press.dart';
import '../../ui/sheet.dart';
import 'plan_notice.dart';

/// The picker: every model, banded rows padlocked from the access snapshot.
/// A locked row opens the plan notice, never a checkout. Resolves with the
/// chosen id, or null when dismissed.
Future<String?> showModelSheet(BuildContext context, {required String model}) => showGkSheet<String>(
      context,
      header: SheetHeader(eyebrow: 'Model', onClose: () => Navigator.of(context).pop()),
      builder: (context) => _ModelList(model: model),
    );

class _ModelList extends ConsumerWidget {
  const _ModelList({required this.model});
  final String model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(accessProvider).value;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        for (final m in models)
          _ModelRow(
            def: m,
            selected: m.id == model,
            granted: modelAccess(snapshot, m.id).granted,
            onPressed: () {
              final access = modelAccess(snapshot, m.id);
              if (!access.granted) {
                showPlanNotice(context, PlanDenied(what: m.name, requiredPlan: access.requiredPlan));
                return;
              }
              Navigator.of(context).pop(m.id);
            },
          ),
      ],
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.def, required this.selected, required this.granted, required this.onPressed});
  final ModelDef def;
  final bool selected;
  final bool granted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = !granted ? Ds.faint : (selected ? Ds.accent : Ds.soft);
    return Press(
      onPressed: onPressed,
      semanticLabel: def.name,
      builder: (context, pressed) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        color: pressed ? Ds.veil : const Color(0x00000000),
        child: Row(
          children: [
            Expanded(
              child: Text(
                def.name,
                style: DsStyle.ui(DsText.body, color: ink, weight: selected ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
            if (!granted)
              Icon(LucideIcons.lock, size: 14, color: Ds.faint)
            else if (selected)
              Icon(LucideIcons.check, size: 16, color: Ds.accent),
          ],
        ),
      ),
    );
  }
}
