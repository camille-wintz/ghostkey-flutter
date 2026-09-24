import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/errors.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/sheet.dart';
import '../../ui/text.dart';

/// One of the author's fields on a card, written in a sheet: the name, the
/// notes, the appearance, one GMC answer. A sheet rather than a field on the
/// page, because a box that saves on blur inside a scrolling page is a save
/// the author never sees happen — here Save is the save, and the sheet stays
/// up with the error when it fails.
///
/// [onSave] gets the trimmed text and throws to refuse it. Saving what was
/// already there closes without a write.
Future<void> showEntityTextSheet(
  BuildContext context, {
  required String eyebrow,
  required String initial,
  required Future<void> Function(String value) onSave,
  String? trailing,
  String? placeholder,
  String? hint,
  bool multiline = true,
  bool allowEmpty = true,
}) =>
    showGkSheet<void>(
      context,
      builder: (context) => _EntityTextSheet(
        eyebrow: eyebrow,
        trailing: trailing,
        initial: initial,
        placeholder: placeholder,
        hint: hint,
        multiline: multiline,
        allowEmpty: allowEmpty,
        onSave: onSave,
      ),
    );

class _EntityTextSheet extends StatefulWidget {
  const _EntityTextSheet({
    required this.eyebrow,
    required this.trailing,
    required this.initial,
    required this.placeholder,
    required this.hint,
    required this.multiline,
    required this.allowEmpty,
    required this.onSave,
  });

  final String eyebrow;
  final String? trailing;
  final String initial;
  final String? placeholder;
  final String? hint;
  final bool multiline;
  final bool allowEmpty;
  final Future<void> Function(String value) onSave;

  @override
  State<_EntityTextSheet> createState() => _EntityTextSheetState();
}

class _EntityTextSheetState extends State<_EntityTextSheet> {
  late final _text = TextEditingController(text: widget.initial);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _text.text.trim();
    if (_saving || (!widget.allowEmpty && value.isEmpty)) return;
    if (value == widget.initial.trim()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(value);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _close() {
    if (!_saving) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(eyebrow: widget.eyebrow, trailing: widget.trailing, onClose: _close),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: ListenableBuilder(
                  listenable: _text,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.hint case final hint?) ...[
                        UiText(hint, step: DsText.ui, color: Ds.low),
                        const SizedBox(height: 12),
                      ],
                      GkField(
                        controller: _text,
                        placeholder: widget.placeholder,
                        autofocus: true,
                        enabled: !_saving,
                        minLines: widget.multiline ? 4 : 1,
                        maxLines: widget.multiline ? 10 : 1,
                        textInputAction: widget.multiline ? null : TextInputAction.done,
                        onSubmitted: widget.multiline ? null : (_) => _save(),
                      ),
                      const SizedBox(height: 16),
                      if (_error case final error?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: UiText(error, step: DsText.ui, color: Ds.destructive),
                        ),
                      GkButton(
                        label: 'Save',
                        wide: true,
                        busy: _saving,
                        disabled: !widget.allowEmpty && _text.text.trim().isEmpty,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
