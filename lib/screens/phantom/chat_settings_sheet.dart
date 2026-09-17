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

/// The conversation's settings, the desktop's "Chat settings" modal: which
/// model answers, and whether it may write in the manuscript. Both apply from
/// the next message on, so each choice lands the moment it is pressed and the
/// sheet stays open to show it.
Future<void> showChatSettingsSheet(
  BuildContext context, {
  required String model,
  required bool manuscriptWrites,
  required ValueChanged<String> onModel,
  required ValueChanged<bool> onManuscriptWrites,
}) =>
    showGkSheet<void>(
      context,
      header: SheetHeader(eyebrow: 'Chat settings', onClose: () => Navigator.of(context).pop()),
      builder: (context) => _ChatSettings(
        model: model,
        manuscriptWrites: manuscriptWrites,
        onModel: onModel,
        onManuscriptWrites: onManuscriptWrites,
      ),
    );

class _ChatSettings extends ConsumerStatefulWidget {
  const _ChatSettings({
    required this.model,
    required this.manuscriptWrites,
    required this.onModel,
    required this.onManuscriptWrites,
  });

  final String model;
  final bool manuscriptWrites;
  final ValueChanged<String> onModel;
  final ValueChanged<bool> onManuscriptWrites;

  @override
  ConsumerState<_ChatSettings> createState() => _ChatSettingsState();
}

class _ChatSettingsState extends ConsumerState<_ChatSettings> {
  late String _model = widget.model;
  late bool _writes = widget.manuscriptWrites;

  void _pickModel(ModelDef def) {
    final access = modelAccess(ref.read(accessProvider).value, def.id);
    if (!access.granted) {
      showPlanNotice(context, PlanDenied(what: def.name, requiredPlan: access.requiredPlan));
      return;
    }
    setState(() => _model = def.id);
    widget.onModel(def.id);
  }

  void _pickWrites(bool writes) {
    setState(() => _writes = writes);
    widget.onManuscriptWrites(writes);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(accessProvider).value;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        const _SectionLabel('Manuscript'),
        _SettingRow(
          icon: LucideIcons.penLine,
          label: 'Write in the manuscript',
          detail: 'The assistant may change a passage of a chapter when you ask it to.',
          selected: _writes,
          onPressed: () => _pickWrites(true),
        ),
        _SettingRow(
          icon: LucideIcons.lock,
          label: 'Read only',
          detail: 'The assistant reads and advises; it never touches the text.',
          selected: !_writes,
          onPressed: () => _pickWrites(false),
        ),
        const _SectionLabel('Model'),
        for (final def in models)
          _SettingRow(
            label: def.name,
            selected: def.id == _model,
            locked: !modelAccess(snapshot, def.id).granted,
            onPressed: () => _pickModel(def),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: Text(text.toUpperCase(), style: DsStyle.eyebrow(color: Ds.accent300)),
      );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.detail,
    this.locked = false,
  });

  final IconData? icon;
  final String label;
  final String? detail;
  final bool selected;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = locked ? Ds.faint : (selected ? Ds.accent : Ds.soft);
    return Press(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        color: pressed ? Ds.veil : const Color(0x00000000),
        child: Row(
          crossAxisAlignment: detail == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(icon, size: 15, color: selected ? Ds.accent : Ds.mid),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: DsStyle.ui(DsText.body, color: ink, weight: selected ? FontWeight.w600 : FontWeight.w400),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (locked)
              Icon(LucideIcons.lock, size: 14, color: Ds.faint)
            else if (selected)
              Icon(LucideIcons.check, size: 16, color: Ds.accent),
          ],
        ),
      ),
    );
  }
}
