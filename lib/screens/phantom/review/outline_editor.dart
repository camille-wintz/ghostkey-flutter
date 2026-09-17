import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/providers.dart';
import '../../../chat/review/outline_autosave.dart';
import '../../../ds/tokens.dart';
import '../../../ui/text.dart';

/// The author's outline, editable, saving as they type. Read only while a
/// chat turn runs: the turn may be writing the same row, and the route is
/// last-write-wins.
class OutlineEditor extends ConsumerStatefulWidget {
  const OutlineEditor({super.key, required this.projectId, required this.initial});
  final String projectId;

  /// Read once, on open; this page never re-reads under the author's typing.
  final String initial;

  @override
  ConsumerState<OutlineEditor> createState() => _OutlineEditorState();
}

class _OutlineEditorState extends ConsumerState<OutlineEditor> {
  late final OutlineAutosave _autosave = OutlineAutosave(projectId: widget.projectId, initial: widget.initial);

  @override
  void dispose() {
    _autosave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final turnRunning = ref.watch(chatTurnProvider(widget.projectId).select((s) => s.sending));
    return Column(
      children: [
        Expanded(
          child: TextField(
            controller: _autosave.text,
            readOnly: turnRunning,
            maxLines: null,
            expands: true,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            textAlignVertical: TextAlignVertical.top,
            cursorColor: Ds.accent,
            style: DsStyle.ui(DsText.body, color: Ds.ink).copyWith(height: 1.6),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              hintText: 'Write the outline — the story as you plan it.',
              hintStyle: DsStyle.ui(DsText.body, color: Ds.faint),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _autosave,
          builder: (context, _) {
            final line = turnRunning
                ? 'Read only while the chat answers'
                : switch (_autosave.status) {
                    OutlineSaveStatus.saved => null,
                    OutlineSaveStatus.dirty || OutlineSaveStatus.saving => 'Saving…',
                    OutlineSaveStatus.failed => 'Not saved. ${_autosave.error ?? ''}',
                  };
            if (line == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: UiText(
                line,
                step: DsText.ui,
                color: _autosave.status == OutlineSaveStatus.failed ? Ds.destructive : Ds.low,
              ),
            );
          },
        ),
      ],
    );
  }
}
