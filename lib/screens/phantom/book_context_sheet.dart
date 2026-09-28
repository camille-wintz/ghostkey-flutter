import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/errors.dart';
import '../../server/projects/api.dart';
import '../../server/providers.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/sheet.dart';

/// The desktop's "Book context" dialog: one freeform field the chat reads the
/// manuscript by. Saving an emptied field clears the brief.
Future<void> showBookContextSheet(BuildContext context, {required String projectId, required String current}) =>
    showGkSheet<void>(
      context,
      header: SheetHeader(eyebrow: 'Book context', onClose: () => Navigator.of(context).pop()),
      builder: (context) => _BookContextForm(projectId: projectId, current: current),
    );

class _BookContextForm extends ConsumerStatefulWidget {
  const _BookContextForm({required this.projectId, required this.current});
  final String projectId;
  final String current;

  @override
  ConsumerState<_BookContextForm> createState() => _BookContextFormState();
}

class _BookContextFormState extends ConsumerState<_BookContextForm> {
  late final TextEditingController _context = TextEditingController(text: widget.current);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _context.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await saveAuthorBrief(widget.projectId, _context.text);
      ref.invalidate(projectProvider(widget.projectId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Anything that helps it read your book the way you mean it — genre, audience, where '
          'the draft stands, what you want feedback on.',
          style: DsStyle.ui(DsText.body, color: Ds.mid),
        ),
        const SizedBox(height: 14),
        GkField(
          controller: _context,
          placeholder:
              'e.g. Literary science fiction for an adult upmarket readership, second revised '
              'draft. I mostly want feedback on pacing and the sister’s arc.',
          autofocus: true,
          enabled: !_saving,
          minLines: 6,
          maxLines: 12,
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 10),
          Text('Couldn’t save: $error', style: DsStyle.ui(DsText.ui, color: Ds.destructive)),
        ],
        const SizedBox(height: 14),
        GkButton(label: 'Save', wide: true, busy: _saving, onPressed: _saving ? null : _save),
      ],
    ),
  );
}
