import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../server/errors.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/text.dart';
import '../../veil/dossier_title.dart';
import 'editor_leave_guard.dart';
import 'editor_screen_header.dart';

/// The dossier text on its own screen: the whole page is the field, because
/// a dossier is pages long and a sheet holds a paragraph. Add title starts a
/// `## ` section at the caret — the markdown the reading page sets as titles
/// — so the author never needs the syntax. Save is the save; leaving with
/// changes asks first. The phone web's `DossierEditorScreen.tsx`.
///
/// [onSave] gets the trimmed text and throws to refuse it; saving what was
/// already there leaves without a write.
class DossierEditorScreen extends StatefulWidget {
  const DossierEditorScreen({super.key, required this.name, required this.initial, required this.onSave});
  final String name;
  final String initial;
  final Future<void> Function(String value) onSave;

  @override
  State<DossierEditorScreen> createState() => _DossierEditorScreenState();
}

class _DossierEditorScreenState extends State<DossierEditorScreen> {
  late final _text = TextEditingController(text: widget.initial);
  final _focus = FocusNode();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _dirty => _text.text.trim() != widget.initial.trim();

  void _addTitle() {
    final at = _text.selection.isValid ? _text.selection.start : _text.text.length;
    final next = insertDossierTitle(_text.text, at);
    _text.value = TextEditingValue(text: next.text, selection: TextSelection.collapsed(offset: next.caret));
    _focus.requestFocus();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_text.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _text,
        builder: (context, _) => EditorLeaveGuard(
          dirty: _dirty,
          saving: _saving,
          eyebrow: 'Dossier',
          message: 'What you wrote here since opening the dossier will be lost.',
          child: Scaffold(
            backgroundColor: Ds.void_,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EditorScreenHeader(
                    eyebrow: 'Dossier',
                    name: widget.name,
                    onBack: () => Navigator.of(context).maybePop(),
                    onSave: _save,
                    saving: _saving,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        GkButton(
                          label: 'Add title',
                          variant: ButtonVariant.outline,
                          leading: Icon(LucideIcons.heading, size: 16, color: Ds.soft),
                          disabled: _saving,
                          onPressed: _addTitle,
                        ),
                      ],
                    ),
                  ),
                  if (_error case final error?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: UiText(error, step: DsText.ui, color: Ds.destructive),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: GkField(
                        controller: _text,
                        focusNode: _focus,
                        expands: true,
                        enabled: !_saving,
                        maxLength: maxEntityNotes,
                        placeholder: 'Who they are, where they come from, what they want.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
