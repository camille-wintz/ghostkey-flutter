import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../autosave/field_autosave.dart';
import '../../../chat/providers.dart';
import '../../../mara/outline_text.dart';
import '../../mara/outline/outline_editor.dart';

/// The outline editor as the chat opens it: read only while a turn runs, since
/// the turn may be writing the same row and the route is last-write-wins.
class OutlineReviewEditor extends ConsumerStatefulWidget {
  const OutlineReviewEditor({super.key, required this.projectId, required this.initial});
  final String projectId;

  /// Read once, on open; this page never re-reads under the author's typing.
  final String initial;

  @override
  ConsumerState<OutlineReviewEditor> createState() => _OutlineReviewEditorState();
}

class _OutlineReviewEditorState extends ConsumerState<OutlineReviewEditor> {
  late final FieldAutosave _autosave =
      outlineAutosave(ProviderScope.containerOf(context, listen: false), widget.projectId, widget.initial);

  @override
  void dispose() {
    _autosave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final turnRunning = ref.watch(chatTurnProvider(widget.projectId).select((s) => s.sending));
    return OutlineEditor(autosave: _autosave, readOnly: turnRunning, readOnlyNote: 'Read only while the chat answers');
  }
}
