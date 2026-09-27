import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../server/errors.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/text.dart';
import '../../veil/gmc_draft.dart';
import 'editor_leave_guard.dart';
import 'editor_screen_header.dart';

/// A character's GMC written on its own screen: one block per question, what
/// it asks under it, a field per side. The fields hold the author's answers
/// ([BibleEntity.gmc]); where one is empty and the dossier has an answer,
/// that answer is its placeholder, and one button copies every such answer
/// in, to be kept or reworded. Save writes only the cells that changed
/// ([GmcDraft]). The phone web's `GmcEditorScreen.tsx`.
///
/// [onSave] gets the changed cells, trimmed — an empty one clears it — and
/// throws to refuse them.
class GmcEditorScreen extends StatefulWidget {
  const GmcEditorScreen({
    super.key,
    required this.name,
    required this.authored,
    required this.glance,
    required this.onSave,
  });

  final String name;
  final Map<String, String> authored;
  final List<DossierGlanceItem> glance;
  final Future<void> Function(Map<String, String> cells) onSave;

  @override
  State<GmcEditorScreen> createState() => _GmcEditorScreenState();
}

class _GmcEditorScreenState extends State<GmcEditorScreen> {
  late final _draft = GmcDraft(authored: widget.authored, glance: widget.glance);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final cells = _draft.changed;
    if (cells.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(cells);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _draft.changes,
        builder: (context, _) => EditorLeaveGuard(
          dirty: _draft.dirty,
          saving: _saving,
          eyebrow: 'Goal, motivation, conflict',
          message: 'The answers you changed here will be lost.',
          child: Scaffold(
            backgroundColor: Ds.void_,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EditorScreenHeader(
                    eyebrow: 'Goal, motivation, conflict',
                    name: widget.name,
                    onBack: () => Navigator.of(context).maybePop(),
                    onSave: _save,
                    saving: _saving,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 48 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        if (_error case final error?)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: UiText(error, step: DsText.ui, color: Ds.destructive),
                          ),
                        if (_draft.canFill)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              children: [
                                GkButton(
                                  label: "Use the dossier's answers",
                                  variant: ButtonVariant.outline,
                                  leading: Icon(LucideIcons.bookOpenText, size: 16, color: Ds.soft),
                                  disabled: _saving,
                                  onPressed: _draft.fill,
                                ),
                              ],
                            ),
                          ),
                        for (final (i, question) in glanceGmcQuestions.indexed) ...[
                          if (i > 0) const SizedBox(height: 28),
                          Text(question, style: DsStyle.prose(DsText.prose, color: Ds.accent200, weight: FontWeight.w600)),
                          Text(glanceGmcMeaning[question]!, style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
                          for (final side in glanceGmcSides) ...[
                            const SizedBox(height: 12),
                            Eyebrow(side, semibold: false),
                            const SizedBox(height: 6),
                            _cell(gmcLabel(side, question)),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _cell(String label) {
    final suggestion = _draft.suggestion(label);
    return GkField(
      controller: _draft.field(label),
      placeholder: suggestion.isNotEmpty ? suggestion : 'Not written yet',
      enabled: !_saving,
      minLines: 2,
      maxLines: 8,
      maxLength: 2000,
    );
  }
}
