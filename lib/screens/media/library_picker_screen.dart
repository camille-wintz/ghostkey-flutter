import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../chat/quota_feature.dart';
import '../../ds/tokens.dart';
import '../../media/access.dart';
import '../../media/draw_run.dart';
import '../../media/folder_filter.dart';
import '../../media/library.dart';
import '../../media/photo.dart';
import '../../media/picker_prefs.dart';
import '../../media/picker_selection.dart';
import '../../server/dto/media.dart';
import '../../server/errors.dart';
import '../../server/media/api.dart';
import '../../server/providers.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/lock_notice.dart';
import '../../ui/name_sheet.dart';
import '../../ui/notice_modal.dart';
import 'add_picture_sheet.dart';
import 'draw_tab.dart';
import 'folder_actions_sheet.dart';
import 'library_tab.dart';
import 'move_to_folder_sheet.dart';
import 'picker_title_bar.dart';
import 'picture_actions_sheet.dart';

/// Open the series' media library to pick pictures, and answer with the
/// pick — null when closed. [multi] toggles and commits on "Add N" (a
/// gallery); otherwise the first tap is the answer (a portrait, the chat).
/// [markIds] are pictures already on the card: ticked, not pickable.
/// [prompt] seeds the Draw tab, and opens on it when the author has never
/// tapped a tab; [openOnDraw] opens on it regardless (Veil's "Draw one").
Future<List<MediaItem>?> openLibraryPicker(
  BuildContext context, {
  required String projectId,
  bool multi = false,
  Set<String> markIds = const {},
  String? prompt,
  DrawSize drawSize = DrawSize.square,
  bool openOnDraw = false,
}) =>
    Navigator.of(context).push<List<MediaItem>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LibraryPickerScreen(
          projectId: projectId,
          multi: multi,
          markIds: markIds,
          prompt: prompt,
          drawSize: drawSize,
          openOnDraw: openOnDraw,
        ),
      ),
    );

/// The library as a picker, the only way the phone reaches it: two tabs,
/// Media library and Draw, as on the desk. The desk's `MediaPickerModal`.
class LibraryPickerScreen extends ConsumerStatefulWidget {
  const LibraryPickerScreen({
    super.key,
    required this.projectId,
    this.multi = false,
    this.markIds = const {},
    this.prompt,
    this.drawSize = DrawSize.square,
    this.openOnDraw = false,
  });
  final String projectId;
  final bool multi;
  final Set<String> markIds;
  final String? prompt;
  final DrawSize drawSize;
  final bool openOnDraw;

  @override
  ConsumerState<LibraryPickerScreen> createState() => _LibraryPickerScreenState();
}

class _LibraryPickerScreenState extends ConsumerState<LibraryPickerScreen> {
  late final _selection = PickerSelection(multi: widget.multi, marked: widget.markIds);
  late final _draw = DrawRun(prompt: widget.prompt ?? '', size: widget.drawSize);
  final _search = TextEditingController();
  Timer? _debounce;

  /// Null until the device has said where the author was.
  LibraryTab? _tab;
  String _folderWire = FolderFilter.all.wire;
  String _query = '';
  int _uploading = 0;
  String? _notice;

  String get _projectId => widget.projectId;
  ProviderContainer get _container => ProviderScope.containerOf(context, listen: false);

  @override
  void initState() {
    super.initState();
    unawaited(_restorePlace());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _draw.dispose();
    super.dispose();
  }

  Future<void> _restorePlace() async {
    final place = await readPickerPlace(_projectId);
    if (!mounted) return;
    final suggestsDraw = widget.prompt?.trim().isNotEmpty ?? false;
    setState(() {
      _tab = widget.openOnDraw
          ? LibraryTab.draw
          : place.tab ?? (suggestsDraw ? LibraryTab.draw : LibraryTab.library);
      _folderWire = place.folder ?? _folderWire;
    });
  }

  void _pickTab(LibraryTab tab) {
    setState(() => _tab = tab);
    unawaited(rememberPickedTab(tab));
  }

  void _openFolder(FolderFilter folder) {
    setState(() => _folderWire = folder.wire);
    unawaited(rememberFolder(_projectId, folder.wire));
  }

  void _onQuery(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  FolderFilter _folderIn(MediaLibrary? library) =>
      FolderFilter.fromWire(_folderWire, folders: library?.folders ?? const []);

  void _tap(MediaItem item) {
    final pick = _selection.tap(item);
    if (pick != null) return Navigator.of(context).pop(pick);
    setState(() {});
  }

  void _use(MediaItem item) {
    if (!widget.multi) return Navigator.of(context).pop([item]);
    if (!_selection.isPicked(item.id)) _tap(item);
  }

  /// The failure in a notice: there is no sheet up to hold it.
  void _failed(String title, Object e) => unawaited(showNoticeModal(
        context,
        eyebrow: 'Media library',
        title: title,
        action: 'Got it',
        children: [NoticeText(messageFor(e))],
      ));

  // ── Ways in ─────────────────────────────────────────────────────────────

  Future<void> _add() async {
    final source = await showAddPictureSheet(context);
    if (source != null && mounted) await _upload(source);
  }

  /// A photo into the open folder, picked as soon as the library has it.
  Future<void> _upload(PhotoSource source) async {
    final PickedPhoto? photo;
    try {
      photo = await pickPhoto(source);
    } on PhotoUnreadable {
      setState(() => _notice = PhotoUnreadable.message);
      return;
    } catch (e) {
      debugPrint('[media] the photo picker failed: $e');
      setState(() => _notice = source == PhotoSource.camera
          ? "The camera wouldn't open."
          : "Your photos wouldn't open.");
      return;
    }
    if (photo == null || !mounted) return;
    final folderId = _folderIn(ref.read(libraryProvider(_projectId)).value).landingFolderId;
    setState(() {
      _uploading++;
      _notice = null;
      _tab = LibraryTab.library;
    });
    try {
      final item = await uploadPicture(_container, _projectId, photo, folderId: folderId);
      if (mounted) setState(() => _selection.land(item));
    } catch (e) {
      if (mounted) {
        setState(() => _notice = switch (e) {
              ServerError(code: 'unsupported_type') => PhotoUnreadable.message,
              ServerError(code: 'content_too_large') => 'That photo is too large for the library.',
              _ => "The photo didn't go in. ${messageFor(e)}",
            });
      }
    } finally {
      if (mounted) setState(() => _uploading--);
    }
  }

  Future<void> _drawNow() async {
    final folderId = _folderIn(ref.read(libraryProvider(_projectId)).value).landingFolderId;
    final container = _container;
    final outcome = await _draw.start(
      (prompt, size) => drawPicture(container, _projectId, prompt: prompt, size: size, folderId: folderId),
    );
    if (!mounted) return;
    switch (outcome) {
      case DrawDone(:final item):
        // Lands on the library without counting as the author's tab pick.
        setState(() {
          _selection.land(item);
          _tab = LibraryTab.library;
        });
      case DrawLocked(:final state):
        explainLock(context, state, 'Drawing pictures');
      case DrawSpent() || DrawFailed() || null:
        break;
    }
  }

  // ── A picture's actions ─────────────────────────────────────────────────

  Future<void> _hold(MediaItem item) async {
    final action = await showPictureActions(context, item: item, canUse: !_selection.isMarked(item.id));
    if (action == null || !mounted) return;
    switch (action) {
      case PictureAction.use:
        _use(item);
      case PictureAction.rename:
        await _rename(item);
      case PictureAction.move:
        await _move(item);
      case PictureAction.remove:
        await _remove(item);
    }
  }

  Future<void> _rename(MediaItem item) async {
    final title = await showNameSheet(
      context,
      eyebrow: 'Rename picture',
      current: item.title,
      action: 'Rename',
      placeholder: 'What it shows',
      maxLength: 300,
    );
    if (title == null || title == item.title || !mounted) return;
    try {
      await renamePicture(_container, _projectId, item.id, title);
    } catch (e) {
      if (mounted) _failed("The picture wasn't renamed", e);
    }
  }

  Future<void> _move(MediaItem item) async {
    final folders = foldersInOrder(ref.read(libraryProvider(_projectId)).value?.folders ?? const []);
    final to = await showMoveToFolderSheet(context, folders: folders, current: item.folderId);
    if (to == null || !mounted) return;
    try {
      await movePicture(_container, _projectId, item.id, to.folderId);
    } catch (e) {
      if (mounted) _failed("The picture wasn't moved", e);
    }
  }

  /// Asked first, with the number of cards it will come off — read at the
  /// moment of asking, since the listing doesn't carry it.
  Future<void> _remove(MediaItem item) async {
    final cards = await cardsShowing(_projectId, item.id);
    if (!mounted) return;
    final ok = await showConfirmSheet(
      context,
      eyebrow: 'Remove from library',
      title: 'Remove this picture from the library?',
      message: removeMessage(cards),
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await removePicture(_container, _projectId, item.id);
      if (mounted) setState(() => _selection.forget(item.id));
    } catch (e) {
      if (mounted) _failed("The picture wasn't removed", e);
    }
  }

  // ── Folders ─────────────────────────────────────────────────────────────

  /// A name for a folder, asked again with the reason when the series
  /// already has one called that. Null when the author backs out.
  Future<String?> _folderName({
    required String eyebrow,
    required String action,
    String current = '',
    String? message,
  }) =>
      showNameSheet(
        context,
        eyebrow: eyebrow,
        current: current,
        action: action,
        message: message,
        placeholder: 'Folder name',
        maxLength: 120,
      );

  Future<void> _newFolder({String current = '', String? message}) async {
    final name = await _folderName(eyebrow: 'New folder', action: 'Create', current: current, message: message);
    if (name == null || !mounted) return;
    try {
      final folder = await createFolder(_container, _projectId, name);
      if (mounted) _openFolder(InFolder(folder.id));
    } on ServerError catch (e) {
      if (!mounted) return;
      if (e.code == 'name_taken') return _newFolder(current: name, message: folderNameTaken);
      _failed("The folder wasn't made", e);
    } catch (e) {
      if (mounted) _failed("The folder wasn't made", e);
    }
  }

  Future<void> _holdFolder(MediaFolder folder) async {
    final action = await showFolderActions(context, name: folder.name);
    if (action == null || !mounted) return;
    switch (action) {
      case FolderAction.rename:
        await _renameFolder(folder);
      case FolderAction.delete:
        await _deleteFolder(folder);
    }
  }

  Future<void> _renameFolder(MediaFolder folder, {String? current, String? message}) async {
    final name = await _folderName(
      eyebrow: 'Rename folder',
      action: 'Rename',
      current: current ?? folder.name,
      message: message,
    );
    if (name == null || name == folder.name || !mounted) return;
    try {
      await renameFolder(_container, _projectId, folder.id, name);
    } on ServerError catch (e) {
      if (!mounted) return;
      if (e.code == 'name_taken') return _renameFolder(folder, current: name, message: folderNameTaken);
      _failed("The folder wasn't renamed", e);
    } catch (e) {
      if (mounted) _failed("The folder wasn't renamed", e);
    }
  }

  Future<void> _deleteFolder(MediaFolder folder) async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: 'Delete folder',
      title: "Delete '${folder.name}'?",
      message: 'Its pictures stay in your library, unfiled.',
      confirmLabel: 'Delete folder',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await deleteFolder(_container, _projectId, folder.id);
      if (mounted && _folderWire == InFolder(folder.id).wire) _openFolder(FolderFilter.all);
    } catch (e) {
      if (mounted) _failed("The folder wasn't deleted", e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryRead = ref.watch(libraryProvider(_projectId));
    final library = libraryRead.value;
    final folder = _folderIn(library);
    final searching = _query.isNotEmpty;
    final pictures = searching
        ? ref.watch(librarySearchProvider((projectId: _projectId, query: _query, folder: folder)))
        : libraryRead.whenData((l) => picturesIn(l, folder));
    final gate = ref.watch(capabilityProvider(drawCapability));
    final quota = quotaLine(ref.watch(quotaProvider).value?.feature(drawQuotaFeature));
    final tab = _tab;

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        bottom: false,
        child: tab == null
            ? const SizedBox.expand()
            : ListenableBuilder(
                listenable: _draw,
                builder: (context, _) => Column(
                  children: [
                    PickerTitleBar(
                      tab: tab,
                      onTab: _pickTab,
                      onClose: () => Navigator.of(context).pop(),
                      drawing: _draw.busy,
                      commitLabel: _selection.commitLabel,
                      onCommit: () => Navigator.of(context).pop(_selection.picked),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: tab.index,
                        children: [
                          LibraryTabView(
                            search: _search,
                            onQuery: _onQuery,
                            folders: foldersInOrder(library?.folders ?? const []),
                            folder: folder,
                            onFolder: _openFolder,
                            onFolderHold: _holdFolder,
                            onNewFolder: _newFolder,
                            pictures: pictures,
                            searching: searching,
                            libraryEmpty: library != null && picturesIn(library, FolderFilter.all).isEmpty,
                            selection: _selection,
                            pending: _uploading,
                            onTap: _tap,
                            onHold: _hold,
                            onAdd: _add,
                            onPhoto: _upload,
                            onDraw: () => _pickTab(LibraryTab.draw),
                            onRetry: () => ref.invalidate(libraryProvider(_projectId)),
                            notice: _notice,
                          ),
                          DrawTab(run: _draw, onDraw: _drawNow, locked: !gate.granted, quota: quota),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

const String folderNameTaken = 'You already have a folder called that.';

/// The removal's question, as the desk's `useConfirmRemove` words it: a
/// picture may be on world-bible cards as well as boards, and removing it
/// takes it off them too.
String removeMessage(int cards) {
  final onCards = cards > 0 ? ' and off $cards world-bible card${cards == 1 ? '' : 's'}' : '';
  return "It comes off every board it was pinned to$onCards. This can't be undone.";
}
