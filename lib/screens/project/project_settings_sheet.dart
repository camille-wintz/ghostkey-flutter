import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/projects/api.dart';
import '../../server/projects/covers.dart';
import '../../server/providers.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/press.dart';
import '../../ui/sheet.dart';
import '../../ui/text.dart';

/// The desktop's project settings, on a phone: cover, title, author and the
/// quote style. The series picker stays on the desk.
///
/// The cover and the quote style save the moment they are chosen. Title and
/// author save when the sheet goes away, however it goes — typing is not a
/// commit until the author is done with it.
Future<void> showProjectSettings(BuildContext context, WidgetRef ref, ProjectMeta project) => showGkSheet<void>(
      context,
      maxHeightFraction: 0.92,
      header: SheetHeader(eyebrow: 'Project settings', onClose: () => Navigator.of(context).pop()),
      builder: (_) => ProjectSettingsSheet(
        project: project,
        onSaved: () => _refresh(ref, project.id),
        onDone: (title, author) => _saveNames(context, ref, project, title: title, author: author),
      ),
    );

Future<void> _saveNames(
  BuildContext context,
  WidgetRef ref,
  ProjectMeta project, {
  required String title,
  required String author,
}) async {
  // An emptied title keeps the old one: `name` cannot be blank, and a book
  // with no name has nothing to be found by on the shelf.
  final titleChanged = title.isNotEmpty && title != project.displayTitle;
  final authorChanged = author != project.author;
  if (!titleChanged && !authorChanged) return;
  try {
    await patchProject(
      project.id,
      name: titleChanged ? title : null,
      title: titleChanged ? title : null,
      author: authorChanged ? author : null,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(messageFor(e))));
    }
  }
  _refresh(ref, project.id);
}

void _refresh(WidgetRef ref, String projectId) {
  ref.invalidate(projectProvider(projectId));
  ref.invalidate(projectsProvider);
}

const Map<TypographyMode, (String, String)> _typographyLabels = {
  TypographyMode.curly: ('Curly quotes', '“ ” ‘ ’'),
  TypographyMode.guillemets: ('Guillemets', '« » with French spacing before ; : ! ?'),
  TypographyMode.german: ('Low-high quotes', '„ “ ‚ ‘'),
  TypographyMode.none: ('None', 'Punctuation stays as typed'),
};

enum _CoverBusy { uploading, removing }

class ProjectSettingsSheet extends ConsumerStatefulWidget {
  const ProjectSettingsSheet({super.key, required this.project, required this.onSaved, required this.onDone});
  final ProjectMeta project;

  /// A write landed. The opener's ref does the refetch: an upload can outlive
  /// the sheet, and this state's own ref dies with it.
  final VoidCallback onSaved;

  /// The title and author as the sheet left them, trimmed, once it is gone.
  final void Function(String title, String author) onDone;

  @override
  ConsumerState<ProjectSettingsSheet> createState() => _ProjectSettingsSheetState();
}

class _ProjectSettingsSheetState extends ConsumerState<ProjectSettingsSheet> {
  final _picker = ImagePicker();
  late final _title = TextEditingController(text: widget.project.displayTitle);
  late final _author = TextEditingController(text: widget.project.author);
  _CoverBusy? _coverBusy;
  String? _coverError;

  /// The picked image, drawn at once while it uploads — the cover the author
  /// chose should not wait on their uplink to appear.
  Uint8List? _pickedCover;
  TypographyMode? _typography;
  String? _typographyError;

  @override
  void dispose() {
    widget.onDone(_title.text.trim(), _author.text.trim());
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  String get _projectId => widget.project.id;

  Future<void> _pickCover() async {
    if (_coverBusy != null) return;
    // Covers run about 1600×2560; anything past that is megabytes over a
    // phone's uplink for pixels no screen here draws.
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 3600,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final dot = file.name.lastIndexOf('.');
    final extension = dot < 0 ? 'jpg' : file.name.substring(dot + 1);
    setState(() {
      _pickedCover = bytes;
      _coverBusy = _CoverBusy.uploading;
      _coverError = null;
    });
    try {
      await setProjectCover(_projectId, bytes, extension: extension);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() {
          _pickedCover = null;
          _coverError = messageFor(e);
        });
      }
    } finally {
      if (mounted) setState(() => _coverBusy = null);
    }
  }

  Future<void> _removeCover() async {
    if (_coverBusy != null) return;
    setState(() {
      _coverBusy = _CoverBusy.removing;
      _coverError = null;
    });
    try {
      await removeProjectCover(_projectId);
      widget.onSaved();
      if (mounted) setState(() => _pickedCover = null);
    } catch (e) {
      if (mounted) setState(() => _coverError = messageFor(e));
    } finally {
      if (mounted) setState(() => _coverBusy = null);
    }
  }

  Future<void> _chooseTypography(TypographyMode mode, TypographyMode was) async {
    if (mode == was) return;
    setState(() {
      _typography = mode;
      _typographyError = null;
    });
    try {
      await patchProject(_projectId, typography: mode);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() {
          _typography = was;
          _typographyError = messageFor(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(projectProvider(_projectId)).value;
    final project = data?.project;
    final coverUrl = project != null ? projectCoverUrl(project, data!.assets) : null;
    final typography = _typography ?? project?.typography ?? TypographyMode.curly;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('Cover'),
          const SizedBox(height: 10),
          _CoverSlot(
            picked: _pickedCover,
            coverUrl: coverUrl,
            busy: _coverBusy,
            onChoose: _pickCover,
            onRemove: coverUrl != null || _pickedCover != null ? _removeCover : null,
          ),
          if (_coverError != null) ...[
            const SizedBox(height: 8),
            UiText(_coverError!, step: DsText.ui, color: Ds.destructive),
          ],
          const SizedBox(height: 26),
          const Eyebrow('Title'),
          const SizedBox(height: 8),
          GkField(controller: _title, placeholder: 'My Project', textInputAction: TextInputAction.next),
          const SizedBox(height: 18),
          const Eyebrow('Author'),
          const SizedBox(height: 8),
          GkField(
            controller: _author,
            placeholder: 'Author name',
            autocorrect: false,
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 26),
          const Eyebrow('Quote style'),
          const SizedBox(height: 4),
          UiText(
            'The quote style typing and dictation use for this book. A translation is its own project, with its own setting.',
            step: DsText.ui,
            color: Ds.low,
          ),
          const SizedBox(height: 10),
          for (final mode in TypographyMode.values)
            _TypographyRow(
              title: _typographyLabels[mode]!.$1,
              detail: _typographyLabels[mode]!.$2,
              selected: mode == typography,
              onPressed: () => _chooseTypography(mode, typography),
            ),
          if (_typographyError != null) ...[
            const SizedBox(height: 8),
            UiText(_typographyError!, step: DsText.ui, color: Ds.destructive),
          ],
        ],
      ),
    );
  }
}

class _CoverSlot extends StatelessWidget {
  const _CoverSlot({
    required this.picked,
    required this.coverUrl,
    required this.busy,
    required this.onChoose,
    required this.onRemove,
  });
  final Uint8List? picked;
  final String? coverUrl;
  final _CoverBusy? busy;
  final VoidCallback onChoose;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasCover = picked != null || coverUrl != null;
    final image = switch ((picked, coverUrl)) {
      (final Uint8List bytes, _) => Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      (_, final String url) => Image.network(url, fit: BoxFit.cover, gaplessPlayback: true),
      _ => Center(child: Icon(LucideIcons.imagePlus, size: 22, color: Ds.low)),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Press(
          onPressed: busy == null ? onChoose : null,
          semanticLabel: hasCover ? 'Replace cover' : 'Choose cover image',
          builder: (context, pressed) => Container(
            width: 104,
            height: 156,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: pressed ? Ds.veilHi : Ds.void_,
              border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
              borderRadius: BorderRadius.circular(DsGeom.radius),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(opacity: busy != null ? 0.4 : 1, child: image),
                if (busy != null)
                  Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiText(
                switch (busy) {
                  _CoverBusy.uploading => 'Uploading cover…',
                  _CoverBusy.removing => 'Removing cover…',
                  null => hasCover ? 'Shown on the shelf and behind this book.' : 'No cover yet.',
                },
                step: DsText.ui,
                color: Ds.mid,
              ),
              const SizedBox(height: 12),
              GkButton(
                label: hasCover ? 'Replace' : 'Choose image',
                variant: ButtonVariant.outline,
                disabled: busy != null,
                onPressed: onChoose,
              ),
              if (onRemove != null) ...[
                const SizedBox(height: 8),
                GkButton(
                  label: 'Remove',
                  variant: ButtonVariant.outline,
                  disabled: busy != null,
                  onPressed: onRemove,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TypographyRow extends StatelessWidget {
  const _TypographyRow({required this.title, required this.detail, required this.selected, required this.onPressed});
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: title,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 56),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: pressed ? Ds.veilHi : (selected ? Ds.veil : const Color(0x00000000)),
            border: Border.all(color: selected ? Ds.accentMix(55) : Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UiText(title, color: selected ? Ds.hi : Ds.soft),
                    UiText(detail, step: DsText.ui, color: Ds.low),
                  ],
                ),
              ),
              if (selected) Icon(LucideIcons.check, size: 17, color: Ds.accent),
            ],
          ),
        ),
      );
}
