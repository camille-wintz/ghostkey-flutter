import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/projects/api.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/sheet.dart';
import '../../ui/text.dart';
import 'docx_import.dart';

/// The desk's New novel modal (ghost-key `NewNovelModal`), as a sheet: first
/// the question — a work in progress, or from scratch — then, for scratch,
/// the title. Import goes straight to the file picker; the book is named
/// after its file.
///
/// Both ways end in an open project, which swaps the whole shelf (and this
/// sheet with it) for the book. So the sheet holds while a request is going:
/// the project is being made either way, and the sheet is what opens it.
Future<void> showNewNovelSheet(BuildContext context) => showGkSheet<void>(
      context,
      draggable: false,
      builder: (context) => const _NewNovel(),
    );

enum _Step { choose, scratch }

class _NewNovel extends ConsumerStatefulWidget {
  const _NewNovel();

  @override
  ConsumerState<_NewNovel> createState() => _NewNovelState();
}

class _NewNovelState extends ConsumerState<_NewNovel> {
  final _title = TextEditingController();
  _Step _step = _Step.choose;
  bool _creating = false;
  bool _importing = false;
  String? _importStatus;
  String? _error;

  bool get _pending => _creating || _importing;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _open(ProjectMeta project) {
    ref.invalidate(projectsProvider);
    // No navigate and no pop: the open project decides whether the shelf or
    // the book is mounted at the root, and this sheet goes with the shelf.
    ref.read(activeProjectProvider.notifier).open(project);
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty || _pending) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final project = await createProject(name: slugifyProjectName(title), title: title, starterChapter: true);
      _open(project);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  /// A Word document from a desk becomes a project of its own. The flow —
  /// pick, create, upload, follow the job — lives in docx_import.dart.
  Future<void> _import() async {
    if (_pending) return;
    setState(() {
      _importing = true;
      _importStatus = null;
      _error = null;
    });
    try {
      final result = await importDocxAsProject(
        onProgress: (line) {
          if (mounted) setState(() => _importStatus = line);
        },
        isAlive: () => mounted,
      );
      if (!mounted) return;
      switch (result) {
        // Closing the picker is not a failure and says nothing.
        case DocxImportCancelled():
          break;
        case DocxImportFailed(message: final message):
          setState(() => _error = message);
        case DocxImportDone(project: final project):
          _open(project);
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _importStatus = null;
        });
      }
    }
  }

  void _close() {
    if (!_pending) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_pending,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              eyebrow: 'New novel',
              onBack: _step == _Step.scratch && !_pending
                  ? () => setState(() {
                        _step = _Step.choose;
                        _error = null;
                      })
                  : null,
              onClose: _close,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: switch (_step) {
                  _Step.choose => _choose(),
                  _Step.scratch => _scratch(),
                },
              ),
            ),
          ],
        ),
      );

  Widget _choose() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText('Do you have a work in progress, or do you want to start from scratch?', color: Ds.soft),
          const SizedBox(height: 16),
          ?_errorLine(),
          GkButton(
            label: 'Start from scratch',
            variant: ButtonVariant.outline,
            wide: true,
            disabled: _pending,
            onPressed: () => setState(() {
              _step = _Step.scratch;
              _error = null;
            }),
          ),
          const SizedBox(height: 8),
          GkButton(
            label: 'Import manuscript',
            variant: ButtonVariant.outline,
            wide: true,
            busy: _importing,
            disabled: _creating,
            onPressed: _import,
          ),
          // A hundred-chapter manuscript is minutes of a spinner otherwise,
          // and a spinner that long reads as a hang.
          if (_importStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: UiText(_importStatus!, step: DsText.ui, color: Ds.low, align: TextAlign.center),
            ),
        ],
      );

  Widget _scratch() => ListenableBuilder(
        listenable: _title,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GkField(
              controller: _title,
              placeholder: 'Title',
              autofocus: true,
              autocorrect: false,
              enabled: !_pending,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 16),
            ?_errorLine(),
            GkButton(
              label: 'Create novel',
              wide: true,
              busy: _creating,
              disabled: _title.text.trim().isEmpty,
              onPressed: _create,
            ),
          ],
        ),
      );

  Widget? _errorLine() => _error == null
      ? null
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: UiText(_error!, step: DsText.ui, color: Ds.destructive),
        );
}
