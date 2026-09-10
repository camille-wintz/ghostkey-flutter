import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../autosave/autosave.dart';
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
import 'names_banner.dart';
import 'names_sweep.dart';
import 'notes_names_sheet.dart';
import 'providers.dart';
import 'room_alert.dart';
import 'scrolled_from_top.dart';
import 'title_block.dart';

/// The air between the + and the bar under it, while the keyboard is up.
const double _fabGap = 12;

/// Everything the tools occupy above the keyboard's top edge: the format
/// bar, then the + above it. The page keeps the caret clear of the WHOLE
/// band — a caret parked behind the + is a line the writer cannot see.
const double _toolsHeight = formatBarHeight + _fabGap + fabSize;

/// One document, open: the page, its head, its tools, and the two owners
/// that outlive nothing but this widget — the text and its autosave.
///
/// Keyed by document id by the screen above, so a chapter switch is this
/// State disposing (its autosave flushes with its own ids) and a new one
/// mounting. A rename changes `filename` and nothing else.
///
/// Per-keystroke state never reaches `build`: the count, the tick and the
/// lit format buttons ride on listenables the chrome subscribes to itself.
class ChapterEditor extends ConsumerStatefulWidget {
  const ChapterEditor({
    super.key,
    required this.projectId,
    required this.documentId,
    required this.filename,
    required this.typography,
    required this.onBack,
    required this.onOpenChapters,
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
  final CaptureLauncher? onDictate;
  final CaptureLauncher? onScan;

  @override
  ConsumerState<ChapterEditor> createState() => _ChapterEditorState();
}

class _ChapterEditorState extends ConsumerState<ChapterEditor> {
  late final EditorController _editor = EditorController(typography: widget.typography);
  late final NamesSweep _names = NamesSweep(projectId: widget.projectId, documentId: widget.documentId);
  late final ProviderContainer _container;
  final ValueNotifier<int> _words = ValueNotifier(0);
  final ValueNotifier<FormatActive> _format = ValueNotifier((bold: false, italic: false));
  final ScrolledFromTop _scrolled = ScrolledFromTop();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  Autosave? _autosave;
  ProviderSubscription<AsyncValue<DocumentDto>>? _docSub;
  bool _loaded = false;
  Object? _loadError;
  bool _focused = false;
  bool _menuOpen = false;
  // "Later" is a dismissal for this sitting, not a decision: declining is a
  // hidden entity, and "not now" is not worth a row on anyone's server.
  bool _bannerDismissed = false;
  String _seen = '';
  TextSelection _seenSelection = const TextSelection.collapsed(offset: -1);

  DocumentKey get _key => (projectId: widget.projectId, documentId: widget.documentId);

  @override
  void initState() {
    super.initState();
    // Taken now, not on first use: the chapter-switch flush lands after this
    // State is gone, when the context can no longer answer.
    _container = ProviderScope.containerOf(context, listen: false);
    _editor.textController.addListener(_onValue);
    _scroll.addListener(() => _scrolled.onOffset(_scroll.offset));
    _focus.addListener(_onFocus);
    _docSub = ref.listenManual(documentProvider(_key), (prev, next) {
      next.when(
        data: _load,
        error: (e, _) => setState(() => _loadError = e),
        loading: () {},
      );
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
    if (_canSweep) unawaited(_names.scan());
    setState(() {});
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
  }

  void _onValue() {
    final value = _editor.textController.value;
    final text = value.text;
    if (!identical(text, _seen) && text != _seen) {
      _seen = text;
      _words.value = countWords(text);
    }
    if (value.selection != _seenSelection) {
      _seenSelection = value.selection;
      _syncFormat(text, value.selection);
    }
  }

  void _syncFormat(String text, TextSelection selection) {
    if (!selection.isValid) return;
    final range = (start: selection.start, end: selection.end);
    final next = (
      bold: isWrapped(text, range, InlineMarker.bold),
      italic: isWrapped(text, range, InlineMarker.italic),
    );
    if (next != _format.value) _format.value = next;
  }

  void _onFocus() {
    final focused = _focus.hasFocus;
    if (focused != _focused) setState(() => _focused = focused);
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

  // The keyboard goes down as a capture surface comes up — the session opens
  // on the waveform or the viewfinder, not on a keyboard nobody asked for.
  Future<void> _capture(CaptureLauncher launcher) async {
    setState(() => _menuOpen = false);
    _focus.unfocus();
    // The scan review names the chapter it inserts into; the flow reads it
    // from this registry rather than from the editor.
    ScanContext.chapterTitle = widget.filename.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
    await launcher(context, _editor);
  }

  Future<void> _openNames() async {
    setState(() => _menuOpen = false);
    await NotesNamesSheet.show(
      context,
      projectId: widget.projectId,
      filename: widget.filename,
      candidates: _names.candidates,
      filing: _names.filing,
      onAccept: (c) => _file(c, hidden: false),
      onDecline: (c) => _file(c, hidden: true),
    );
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
    _docSub?.close();
    // The autosave flushes on dispose and the flush outlives it; the
    // controller it reads from has to go AFTER that read.
    _autosave?.dispose();
    _names.dispose();
    _focus.removeListener(_onFocus);
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
      return error != null ? StateScreen(message: messageFor(error)) : const StateScreen(spinner: true, message: 'Loading chapter…');
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
            ),
            if (canSweep)
              ValueListenableBuilder<List<NameCandidate>>(
                valueListenable: _names.candidates,
                builder: (context, candidates, _) => candidates.isEmpty || _bannerDismissed
                    ? const SizedBox.shrink()
                    : NamesBanner(
                        names: candidates.map((c) => c.name).toList(),
                        onReview: _openNames,
                        onLater: () => setState(() => _bannerDismissed = true),
                      ),
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
                      bottomPadding: (_focused ? 0 : bottomPad) + 120 + dock,
                    ),
                  ),
                  if (!_menuOpen)
                    Positioned(
                      right: 20,
                      bottom: _focused ? _fabGap : bottomPad + 22,
                      child: Fab(
                        semanticLabel: 'Add to this chapter',
                        onPressed: () {
                          _focus.unfocus();
                          setState(() => _menuOpen = true);
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (_focused)
              FormatBar(
                active: _format,
                words: _words,
                bottomInset: bottomPad,
                onBold: () => _applyFormat(InlineMarker.bold),
                onItalic: () => _applyFormat(InlineMarker.italic),
                onMic: dictate == null ? null : () => _capture(dictate),
                onCamera: scan == null ? null : () => _capture(scan),
              ),
          ],
        ),
        if (_menuOpen)
          ValueListenableBuilder<List<NameCandidate>>(
            valueListenable: _names.candidates,
            builder: (context, candidates, _) => AddMenu(
              fabBottom: bottomPad + 22,
              newNames: canSweep ? candidates.length : 0,
              onNames: _openNames,
              onPhoto: scan == null ? null : () => _capture(scan),
              onRecord: dictate == null ? null : () => _capture(dictate),
              onClose: () => setState(() => _menuOpen = false),
            ),
          ),
      ],
    );
  }
}

/// The manuscript page: one field in the manuscript's face, at the system's
/// own prose step. Scrolls as a whole so the caret is kept clear of the tools
/// above the keyboard; the field itself never scrolls.
class _Page extends StatelessWidget {
  const _Page({required this.editor, required this.focus, required this.scroll, required this.bottomPadding});
  final EditorController editor;
  final FocusNode focus;
  final ScrollController scroll;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The controller notifies for readOnly only — never per keystroke.
          ListenableBuilder(
            listenable: editor,
            builder: (context, _) => TextField(
              controller: editor.textController,
              focusNode: focus,
              readOnly: editor.readOnly,
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
          // The blank foot of the page is still the page: a tap there puts
          // the caret at the end, as it does on paper.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final end = editor.text.length;
              editor.textController.selection = TextSelection.collapsed(offset: end);
              focus.requestFocus();
            },
            child: SizedBox(height: bottomPadding),
          ),
        ],
      ),
    );
  }
}
