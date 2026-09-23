import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../autosave/autosave.dart';
import '../../rewards/claim.dart';
import '../../rewards/strike.dart';
import '../../rewards/strike_card.dart';
import '../../rewards/strikes.dart';
import '../../core/words.dart';
import '../../dictation/dock_height.dart';
import '../../ds/tokens.dart';
import '../../editor/capture_launchers.dart';
import '../../editor/editor_controller.dart';
import '../../editor/inline_markdown.dart';
import '../../server/dto/bible.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../scan/scan_context.dart';
import '../../server/providers.dart';
import '../../ui/state_screen.dart';
import 'add_menu.dart';
import 'fab.dart';
import 'format_bar.dart';
import 'names_sweep.dart';
import 'notes_names_sheet.dart';
import 'providers.dart';
import 'room_alert.dart';
import 'scrolled_from_top.dart';
import 'title_block.dart';

/// The air between the + and the bar under it.
const double _fabGap = 12;

/// Everything the tools occupy above the keyboard's top edge: the format
/// bar, then the + above it. The page keeps the caret clear of the WHOLE
/// band — a caret parked behind the + is a line the writer cannot see.
const double _toolsHeight = formatBarHeight + _fabGap + fabSize;

/// The air under the last line when the page is at rest, and the room the
/// dictation dock needs on top of it — the dock draws over the page's foot,
/// so the manuscript has to be able to scroll out from under it.
const double _pageFoot = 120;

/// The air the page leaves between the last line and whatever is covering the
/// foot when it follows the writing down. A line and a half: enough to read
/// the line as standing clear, not so much that it costs a screen of
/// manuscript on a page the keyboard has already cut down.
const double _tailAir = 48;

/// One document, open: the page, its head, its tools, and the two owners
/// that outlive nothing but this widget — the text and its autosave.
///
/// Keyed by document id by the screen above, so a chapter switch is this
/// State disposing (its autosave flushes with its own ids) and a new one
/// mounting. A rename changes `filename` and nothing else.
///
/// Per-keystroke state never reaches `build`: the count, the tick and the
/// lit format buttons ride on listenables the chrome subscribes to itself.
///
/// The caret is the page's, and it is always drawn: the field holds focus for
/// as long as the chapter is open, and the keyboard going down is the field
/// going read-only — which closes the input connection without touching focus.
/// So a dismissed keyboard leaves the writer their place instead of nothing,
/// and a tap is what it always was: the caret lands where they tapped and the
/// keyboard comes back with it. Dictation runs over exactly that — the dock
/// does not lock the page, and the keyboard is welcome to be up with it.
///
/// The tools stay up with the caret rather than with the keyboard: a bar that
/// arrives and leaves has to do it against the keyboard's own slide, and it
/// never looks like one movement. Up always, it simply rides the inset.
class ChapterEditor extends ConsumerStatefulWidget {
  const ChapterEditor({
    super.key,
    required this.projectId,
    required this.documentId,
    required this.filename,
    required this.typography,
    required this.onBack,
    required this.onOpenChapters,
    required this.onMenu,
    this.onDictate,
    this.onScan,
  });

  final String projectId;
  final String documentId;
  final String filename;
  final TypographyMode typography;

  final VoidCallback onBack;

  /// Open the chapter list, unfolded from the control that asked for it.
  final void Function(Rect? anchor) onOpenChapters;

  /// Rename or delete this chapter.
  final VoidCallback onMenu;
  final CaptureLauncher? onDictate;
  final CaptureLauncher? onScan;

  @override
  ConsumerState<ChapterEditor> createState() => _ChapterEditorState();
}

class _ChapterEditorState extends ConsumerState<ChapterEditor> with WidgetsBindingObserver {
  late final EditorController _editor = EditorController(typography: widget.typography);
  late final NamesSweep _names = NamesSweep(projectId: widget.projectId, documentId: widget.documentId);
  late final ProviderContainer _container;
  final ValueNotifier<int> _words = ValueNotifier(0);
  final ValueNotifier<FormatActive> _format = ValueNotifier((bold: false, italic: false));
  final ScrolledFromTop _scrolled = ScrolledFromTop();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  Autosave? _autosave;
  // Asks the server what a landed save earned; the server decides, this
  // shows. Made with the autosave and disposed with it.
  RewardClaimer? _rewards;
  // What it earned, struck one card at a time over the foot of the page.
  final RewardStrikes _strikes = RewardStrikes();
  ProviderSubscription<AsyncValue<DocumentDto>>? _docSub;
  bool _loaded = false;
  Object? _loadError;

  /// The keyboard is up and the field takes keystrokes. Its opposite is not
  /// "no caret" — the caret is drawn either way.
  bool _writing = false;

  /// What the last metrics change said, so a keyboard the app did not put
  /// down itself is noticed once.
  bool _keyboardUp = false;

  /// The page is following the foot of the chapter. Set by where the writer's
  /// own scroll came to rest, and by starting a dictation from the end; read
  /// when something grows the page under them.
  bool _stickToEnd = false;
  bool _menuOpen = false;

  /// The + put the keyboard down to open, so closing it with nothing chosen
  /// owes it back — the writer was mid-sentence and only looked.
  bool _menuTookKeyboard = false;
  String _seen = '';
  TextSelection _seenSelection = const TextSelection.collapsed(offset: -1);

  DocumentKey get _key => (projectId: widget.projectId, documentId: widget.documentId);

  @override
  void initState() {
    super.initState();
    // Taken now, not on first use: the chapter-switch flush lands after this
    // State is gone, when the context can no longer answer.
    _container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addObserver(this);
    _editor.textController.addListener(_onValue);
    _scroll.addListener(_onScroll);
    dictationDockHeight.addListener(_onDock);
    _docSub = ref.listenManual(documentProvider(_key), (prev, next) {
      next.when(data: _load, error: (e, _) => setState(() => _loadError = e), loading: () {});
    }, fireImmediately: true);
  }

  @override
  void didUpdateWidget(ChapterEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _editor.typography = widget.typography;
  }

  void _load(DocumentDto doc) {
    if (_loaded) return;
    _loaded = true;
    // The read is done with: nothing re-reads the document under the typing.
    _docSub?.close();
    _docSub = null;
    _editor.setText(doc.content);
    _autosave = Autosave(
      projectId: widget.projectId,
      documentId: widget.documentId,
      text: _editor.textController,
      onSaved: _onSaved,
      onRestore: (content) => _editor.setText(content),
    )..loaded(doc);
    _rewards = RewardClaimer(
      onAwarded: (claim) {
        if (!mounted) return;
        for (final reward in claim.awarded) {
          _strikes.show(strikeFor(reward, claim));
        }
      },
    );
    if (_canSweep) unawaited(_names.scan());
    setState(() {});
    // The page opens with a caret rather than nothing: the field exists as of
    // this build, so focus is asked for once it is in the tree. Read-only, so
    // no keyboard comes with it — and no scroll either, since Flutter only
    // chases the caret for a field that can be typed into.
    WidgetsBinding.instance.addPostFrameCallback((_) => _keepCaret());
  }

  // Absent rather than padlocked when the plan has no sweep: an upsell parked
  // beside the author's own words every writing day is the thing to avoid.
  bool get _canSweep => ref.read(capabilityProvider('veil.name_scan')).granted;

  /// A write landed. The container rather than `ref`: this fires for the
  /// chapter-switch flush too, after this State is gone.
  void _onSaved(DocumentDto doc) {
    _container.invalidate(projectProvider(widget.projectId));
    _container.invalidate(projectWordCountProvider(widget.projectId));
    if (mounted && _canSweep) _names.scheduleRescan();
    // Only while the page is up: a flush after dispose has nowhere to show a
    // reward, and the next open claims it.
    if (mounted) _rewards?.saved();
  }

  void _onValue() {
    final value = _editor.textController.value;
    final text = value.text;
    if (!identical(text, _seen) && text != _seen) {
      _seen = text;
      _words.value = countWords(text);
      _followEnd(value.selection, text);
    }
    if (value.selection != _seenSelection) {
      _seenSelection = value.selection;
      _syncFormat(text, value.selection);
    }
  }

  void _syncFormat(String text, TextSelection selection) {
    if (!selection.isValid) return;
    final range = (start: selection.start, end: selection.end);
    final next = (bold: isWrapped(text, range, InlineMarker.bold), italic: isWrapped(text, range, InlineMarker.italic));
    if (next != _format.value) _format.value = next;
  }

  /// Only a scroll the writer made themselves says where they want to be —
  /// the page's own follow ends at the foot every time, and would keep
  /// answering yes for them.
  void _onScroll() {
    _scrolled.onOffset(_scroll.offset);
    if (_scroll.position.userScrollDirection != ScrollDirection.idle) _stickToEnd = _restingAtEnd;
  }

  /// The dock opened, or grew by a notice: it takes the band the last line was
  /// resting in, and the page's foot grew to match. A page that was following
  /// the end follows it again, so the words keep landing in sight of the
  /// writer rather than behind the dock.
  void _onDock() {
    if (_stickToEnd) _followFoot();
  }

  /// Words reaching the end of the chapter keep the end in view: the page grew
  /// by a line, so it follows that line down, the way a chat does. Only from
  /// the end — a writer working in the middle of the chapter keeps the view
  /// they chose.
  ///
  /// Typing always follows, because the writer is watching the words they are
  /// making. Words that land on their own — a dictated chunk, the paragraph
  /// pass — follow only a page that was already resting at the end, so
  /// scrolling up to read mid-session is not undone by the next chunk.
  void _followEnd(TextSelection selection, String text) {
    if (!_atTextEnd(selection, text)) return;
    if (!_writing && !_stickToEnd) return;
    _followFoot();
  }

  /// The caret is past the last word of the chapter. Trailing blank lines
  /// still count: a chapter that keeps one — most imported ones do — would
  /// otherwise never be written at "the end" at all.
  bool _atTextEnd(TextSelection selection, String text) {
    if (!selection.isCollapsed || selection.baseOffset < 0) return false;
    for (var i = text.length; i > selection.baseOffset; i--) {
      final c = text.codeUnitAt(i - 1);
      if (c != 0x20 && c != 0x0A && c != 0x0D && c != 0x09) return false;
    }
    return true;
  }

  /// Ride the page down to its foot, after the frame: the line that just
  /// arrived is laid out by then, and the foot it pushed down is what the page
  /// is being asked to reach.
  void _followFoot() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      final foot = _pageFoot + dictationDockHeight.value;
      final target = (end - (foot - _tailRoom(MediaQuery.paddingOf(context).bottom))).clamp(0.0, end);
      final gap = target - _scroll.offset;
      // Already there, or past it: the writer scrolled further down than the
      // page would have, and that is theirs to keep.
      if (gap <= 0.5) return;
      // A line or two is the page keeping pace with the writing, and it goes
      // at once — an animation the next word restarts never arrives. A longer
      // way is a chunk landing or the dock opening, and rides.
      if (gap <= 96) {
        _scroll.jumpTo(target);
      } else {
        unawaited(_scroll.animateTo(target, duration: DsMotion.duration, curve: Curves.easeOut));
      }
    });
  }

  /// The page is sitting at the foot of the chapter, give or take a line.
  bool get _restingAtEnd =>
      _scroll.hasClients && _scroll.offset >= _scroll.position.maxScrollExtent - 32;

  /// How much of the page's foot the writer must keep: the band at the bottom
  /// is spoken for — by the + at rest, by the dock while a session runs — and
  /// the last line wants to sit just clear of it. Scrolling the whole foot
  /// into view instead is what puts one line at the top of the screen with
  /// everything else empty under it.
  ///
  /// The dock covers less of the PAGE than it is tall: the page ends at the
  /// format bar, and both of them carry the safe area under it.
  double _tailRoom(double bottomPad) {
    final dock = dictationDockHeight.value;
    final covered = dock > 0 ? dock - formatBarHeight - bottomPad : fabSize + _fabGap;
    return covered + _tailAir;
  }

  /// The keyboard moved. The one case that matters is it going down without
  /// the page asking — Android's back button, the IME's own hide key: Flutter
  /// is not told, so the field would sit there editable under no keyboard.
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final up = View.of(context).viewInsets.bottom > 0;
    if (up == _keyboardUp) return;
    _keyboardUp = up;
    if (!up && _writing) setState(() => _writing = false);
  }

  /// Put the keyboard down and keep the place: read-only closes the input
  /// connection, which is what dismisses the keyboard, and leaves focus — and
  /// so the caret — alone.
  void _rest() {
    if (_writing) setState(() => _writing = false);
    _keepCaret();
  }

  /// Take the keyboard up. A tap on the page asks for this, after the field
  /// has put the caret where the tap landed — so the writer aims with the same
  /// gesture they always did, and the keyboard follows it.
  void _write() {
    if (!_writing) setState(() => _writing = true);
    _focus.requestFocus();
  }

  /// The caret is the page's, not a route's: a sheet or a viewfinder that took
  /// focus gives it back when it goes. Read-only, so this never raises the
  /// keyboard on its own.
  void _keepCaret() {
    if (mounted && !_focus.hasFocus) _focus.requestFocus();
  }

  void _applyFormat(InlineMarker marker) {
    final selection = _editor.selection;
    if (!selection.isValid) return;
    final result = toggleInline(_editor.text, (start: selection.start, end: selection.end), marker);
    _editor.textController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(baseOffset: result.start, extentOffset: result.end),
    );
  }

  /// Opens a capture surface. The keyboard goes down for it — a session opens
  /// on the waveform or the viewfinder, not on a keyboard nobody asked for.
  ///
  /// [overPage] is dictation: its dock runs over this page rather than taking
  /// the screen, so a writer who had the keyboard up when they reached for it
  /// keeps it, and types beside the words landing. The + menu put the keyboard
  /// down to open, so it answers for the reach that went through it.
  Future<void> _capture(CaptureLauncher launcher, {bool overPage = false}) async {
    final keepKeyboard = overPage && (_writing || _menuTookKeyboard);
    // Dictating from the end of the chapter is asking to watch it grow, even
    // from a page parked at the top: the words land out of sight otherwise.
    if (overPage && _editor.caret == _editor.text.length) _stickToEnd = true;
    _menuTookKeyboard = false;
    setState(() => _menuOpen = false);
    if (!keepKeyboard) _rest();
    // The scan review names the chapter it inserts into; the flow reads it
    // from this registry rather than from the editor.
    ScanContext.chapterTitle = widget.filename.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
    // Not awaited yet: a dictation resolves when its dock closes, and the dock
    // is in the tree as of this call — so the keyboard rises to meet it rather
    // than a whole session later.
    final running = launcher(context, _editor);
    if (keepKeyboard) _write();
    await running;
    // Dictation resolves when its dock closes, which is a whole session later:
    // if the writer took the keyboard up in the middle of it, they are still
    // typing, and only a lost caret needs putting back.
    _keepCaret();
  }

  Future<void> _openNames() async {
    _menuTookKeyboard = false;
    setState(() => _menuOpen = false);
    _rest();
    await NotesNamesSheet.show(
      context,
      projectId: widget.projectId,
      filename: widget.filename,
      candidates: _names.candidates,
      filing: _names.filing,
      onAccept: (c) => _file(c, hidden: false),
      onDecline: (c) => _file(c, hidden: true),
    );
    _keepCaret();
  }

  Future<void> _file(NameCandidate candidate, {required bool hidden}) async {
    try {
      await _names.file(candidate, hidden: hidden);
      // The write answers with the bible, but not with the new name placed IN
      // a chapter: its references come from the read that owns them.
      _container.invalidate(bibleProvider(widget.projectId));
    } catch (e) {
      if (mounted) unawaited(showRoomAlert(context, title: 'Could not file that name', message: messageFor(e)));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _docSub?.close();
    // The autosave flushes on dispose and the flush outlives it; the
    // controller it reads from has to go AFTER that read.
    _autosave?.dispose();
    _rewards?.dispose();
    _rewards = null;
    _strikes.dispose();
    _names.dispose();
    dictationDockHeight.removeListener(_onDock);
    _focus.dispose();
    _scroll.dispose();
    _scrolled.dispose();
    _words.dispose();
    _format.dispose();
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final error = _loadError;
      return error != null
          ? StateScreen(message: messageFor(error))
          : const StateScreen(spinner: true, message: 'Loading chapter…');
    }

    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final title = widget.filename.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
    final canSweep = ref.watch(capabilityProvider('veil.name_scan')).granted;
    final dictate = widget.onDictate;
    final scan = widget.onScan;

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            TitleBlock(
              title: title,
              words: _words,
              saved: _autosave!.saved,
              collapsed: _scrolled,
              onBack: widget.onBack,
              onOpenChapters: widget.onOpenChapters,
              onMenu: widget.onMenu,
            ),
            Expanded(
              child: Stack(
                children: [
                  // The dictation dock sits over the page's foot; the page
                  // grows by its height so the insertion point stays visible.
                  ValueListenableBuilder<double>(
                    valueListenable: dictationDockHeight,
                    builder: (context, dock, _) => _Page(
                      editor: _editor,
                      focus: _focus,
                      scroll: _scroll,
                      writing: _writing,
                      onWrite: _write,
                      bottomPadding: _pageFoot + dock,
                    ),
                  ),
                  if (!_menuOpen)
                    Positioned(
                      right: 20,
                      bottom: _fabGap,
                      child: ValueListenableBuilder<List<NameCandidate>>(
                        valueListenable: _names.candidates,
                        builder: (context, candidates, _) => Fab(
                          semanticLabel: 'Add to this chapter',
                          attention: canSweep && candidates.isNotEmpty,
                          onPressed: () {
                            _menuTookKeyboard = _writing;
                            _rest();
                            setState(() => _menuOpen = true);
                          },
                        ),
                      ),
                    ),
                  // A reward, hung from the head of the page under the title
                  // block: a word mark arrives while the author is writing,
                  // and the caret is never up here. A cat gets the full card
                  // — it is the thing being given, and it is worth the room.
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 12,
                    child: ListenableBuilder(
                      listenable: _strikes,
                      builder: (context, _) {
                        final shown = _strikes.current;
                        if (shown == null) return const SizedBox.shrink();
                        return RewardStrikeCard(
                          key: ValueKey(shown.id),
                          strike: shown.strike,
                          compact: shown.strike.cat == null,
                          leaving: shown.leaving,
                          onDismiss: _strikes.dismiss,
                          onGone: () => _strikes.gone(shown.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Drawn through a dictation too, though the dock covers it: the
            // dock is the same panel at the same edge, and a bar that left for
            // the session would move the page's foot twice for nothing. The
            // mic dims all the same — a tap that found its way past the dock
            // must not open a second session.
            ListenableBuilder(
              listenable: _editor,
              builder: (context, _) => FormatBar(
                active: _format,
                words: _words,
                bottomInset: bottomPad,
                onBold: () => _applyFormat(InlineMarker.bold),
                onItalic: () => _applyFormat(InlineMarker.italic),
                onMic: dictate == null || _editor.capturing ? null : () => _capture(dictate, overPage: true),
              ),
            ),
          ],
        ),
        if (_menuOpen)
          ValueListenableBuilder<List<NameCandidate>>(
            valueListenable: _names.candidates,
            builder: (context, candidates, _) => AddMenu(
              // Where the + rests: over the bar, which carries the safe area.
              fabBottom: formatBarHeight + bottomPad + _fabGap,
              newNames: canSweep ? [for (final c in candidates) c.name] : const [],
              onNames: _openNames,
              onPhoto: scan == null || _editor.capturing ? null : () => _capture(scan),
              onRecord: dictate == null || _editor.capturing ? null : () => _capture(dictate, overPage: true),
              onClose: () {
                setState(() => _menuOpen = false);
                if (_menuTookKeyboard) {
                  _menuTookKeyboard = false;
                  _write();
                }
              },
            ),
          ),
      ],
    );
  }
}

/// The manuscript page: one field in the manuscript's face, at the system's
/// own prose step. Scrolls as a whole so the caret is kept clear of the tools
/// above the keyboard; the field itself never scrolls.
///
/// Read-only is how the page holds the keyboard down, so the field asks for
/// the caret to be drawn either way (Flutter's default would take it away with
/// the keyboard). Read-only still moves the caret to a tap and still selects —
/// it only refuses the IME — so the page hands the tap on to [onWrite], and
/// the keyboard arrives at the place the tap just chose.
class _Page extends StatelessWidget {
  const _Page({
    required this.editor,
    required this.focus,
    required this.scroll,
    required this.writing,
    required this.onWrite,
    required this.bottomPadding,
  });
  final EditorController editor;
  final FocusNode focus;
  final ScrollController scroll;
  final bool writing;

  /// The page was tapped: the caret is already there, the keyboard is wanted.
  final VoidCallback onWrite;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 8),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: editor.textController,
              focusNode: focus,
              readOnly: !writing,
              showCursor: true,
              // Runs after the field has placed the caret, so the keyboard
              // comes up at the tap rather than at the old position.
              onTap: onWrite,
              inputFormatters: [editor.inputFormatter],
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              autocorrect: true,
              enableSuggestions: true,
              cursorColor: Ds.accent,
              // The whole band above the keyboard, so a caret never parks
              // behind the +.
              scrollPadding: const EdgeInsets.only(top: 8, bottom: _toolsHeight + 12),
              style: TextStyle(
                fontFamily: DsFonts.manuscript,
                fontSize: DsText.prose.size,
                height: DsText.prose.height,
                color: Ds.ink,
                leadingDistribution: TextLeadingDistribution.even,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                hintText: 'Start writing…',
                hintStyle: TextStyle(
                  fontFamily: DsFonts.manuscript,
                  fontSize: DsText.prose.size,
                  height: DsText.prose.height,
                  color: Ds.faint,
                ),
              ),
            ),
          ),
        ),
        // The blank foot of the page is still the page: a tap there puts the
        // caret at the end, as it does on paper. It fills the viewport under a
        // short chapter — sized to the padding alone, the screen below it was
        // dead to a tap.
        SliverFillRemaining(
          hasScrollBody: false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final end = editor.text.length;
              editor.textController.selection = TextSelection.collapsed(offset: end);
              onWrite();
            },
            child: SizedBox(height: bottomPadding),
          ),
        ),
      ],
    );
  }
}
