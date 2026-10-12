import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../media/note_pieces.dart';
import '../../media/series_notes.dart';
import '../../server/errors.dart';
import '../../ui/room_title_bar.dart';
import '../../ui/state_screen.dart';

/// A series note, read on the phone: its title and length in the bar, its
/// text below, read-only — editing one stays on the desk.
///
/// The text is drawn in pieces, one widget each, built as they scroll into
/// view — a chat export runs to millions of characters.
class SeriesNoteScreen extends ConsumerStatefulWidget {
  const SeriesNoteScreen({super.key, required this.projectId, required this.itemId, required this.title});
  final String projectId;
  final String itemId;

  /// The listing's title, for the bar while the note loads.
  final String title;

  @override
  ConsumerState<SeriesNoteScreen> createState() => _SeriesNoteScreenState();
}

class _SeriesNoteScreenState extends ConsumerState<SeriesNoteScreen> {
  /// The body cut for the version it was cut from.
  ({int version, List<NotePiece> pieces})? _cut;

  SeriesNoteKey get _key => (projectId: widget.projectId, itemId: widget.itemId);

  List<NotePiece> _piecesFor(int version, String body) {
    final cut = _cut;
    if (cut != null && cut.version == version) return cut.pieces;
    final pieces = cutNote(body);
    _cut = (version: version, pieces: pieces);
    return pieces;
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(seriesNoteProvider(_key));
    final loaded = note.value;
    final title = loaded?.item.title.trim().isNotEmpty == true ? loaded!.item.title : widget.title;

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RoomTitleBar(
              title: title.trim().isEmpty ? 'Untitled' : title,
              subtitle: loaded == null ? null : Text('Series note · ${formatWords(loaded.words)} words'),
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: note.when(
                skipLoadingOnReload: true,
                loading: () => const StateScreen(spinner: true, message: 'Opening the note…'),
                error: (e, _) => StateScreen(
                  message: 'The note would not open',
                  detail: messageFor(e),
                  actionLabel: 'Try again',
                  onAction: () => ref.invalidate(seriesNoteProvider(_key)),
                ),
                data: (note) => note.item.body.trim().isEmpty
                    ? const StateScreen(message: 'This note is empty.')
                    : _text(note.item.body, _piecesFor(note.item.version, note.item.body)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(String body, List<NotePiece> pieces) => ListView.builder(
        // The page runs under the gesture bar; the last line clears it.
        padding: EdgeInsets.only(top: 16, bottom: MediaQuery.paddingOf(context).bottom + 32),
        itemCount: pieces.length,
        itemBuilder: (context, i) => _NotePiece(body: body, piece: pieces[i]),
      );
}

class _NotePiece extends StatelessWidget {
  const _NotePiece({required this.body, required this.piece});
  final String body;
  final NotePiece piece;

  @override
  Widget build(BuildContext context) {
    // A piece ends on the line break before the next one starts; the gap
    // below stands in for it, so pieces read as paragraphs.
    final text = body.substring(piece.start, piece.end).trimRight();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Text(text, style: DsStyle.ui(DsText.body, color: Ds.ink)),
    );
  }
}
