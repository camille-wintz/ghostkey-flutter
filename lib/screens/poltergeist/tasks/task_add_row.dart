import 'package:flutter/material.dart';

import '../../../ui/field.dart';
import '../add_button.dart';

/// The capture line at the top of the list: type, Enter, done. The + is a
/// real submit; an empty line submits nothing.
class TaskAddRow extends StatefulWidget {
  const TaskAddRow({super.key, required this.onAdd});
  final void Function(String title) onAdd;

  @override
  State<TaskAddRow> createState() => _TaskAddRowState();
}

class _TaskAddRowState extends State<TaskAddRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    widget.onAdd(title);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: GkField(
                controller: _controller,
                placeholder: 'Add a task',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            AddButton(label: 'Add task', onPressed: _submit, size: 44),
          ],
        ),
      );
}
