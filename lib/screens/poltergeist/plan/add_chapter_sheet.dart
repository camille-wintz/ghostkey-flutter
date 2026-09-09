import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../ui/button.dart';
import '../../../ui/field.dart';
import '../../../ui/sheet.dart';

/// Name a chapter to start at the end of the manuscript. Returns the title,
/// or null when the sheet was put away.
Future<String?> showAddChapterSheet(BuildContext context) => showGkSheet<String>(
      context,
      header: SheetHeader(eyebrow: 'Add a chapter', onClose: () => Navigator.of(context).pop()),
      builder: (context) => const _AddChapterForm(),
    );

class _AddChapterForm extends StatefulWidget {
  const _AddChapterForm();

  @override
  State<_AddChapterForm> createState() => _AddChapterFormState();
}

class _AddChapterFormState extends State<_AddChapterForm> {
  final _controller = TextEditingController();
  var _empty = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'It starts a real, empty chapter at the end of the manuscript, owing its write.',
              style: DsStyle.ui(DsText.ui, color: Ds.mid),
            ),
            const SizedBox(height: 14),
            GkField(
              controller: _controller,
              placeholder: 'Chapter title',
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (value) => setState(() => _empty = value.trim().isEmpty),
            ),
            const SizedBox(height: 14),
            GkButton(label: 'Add chapter', wide: true, disabled: _empty, onPressed: _submit),
          ],
        ),
      );
}
