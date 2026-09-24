import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/projects/api.dart';
import '../../ui/button.dart';
import '../../ui/press.dart';
import '../../ui/sheet.dart';
import '../../ui/text.dart';

/// The desktop's Export, on a phone: the whole manuscript in reading order,
/// assembled by the server and saved where the author picks. DOCX, EPUB and
/// plain text — the desk's PDF needs a renderer this app does not carry.
Future<void> showProjectExport(BuildContext context, ProjectMeta project) => showGkSheet<void>(
      context,
      header: SheetHeader(eyebrow: 'Export', onClose: () => Navigator.of(context).pop()),
      builder: (_) => ProjectExportSheet(project: project),
    );

const Map<ExportFormat, (String, String)> _formatLabels = {
  ExportFormat.docx: ('Word document', '.docx — opens in Word, Pages and Google Docs'),
  ExportFormat.epub: ('EPUB', '.epub — an ebook, with the cover'),
  ExportFormat.txt: ('Plain text', '.txt — the prose, no formatting'),
};

/// Characters a file name cannot carry on at least one of the places the
/// save dialog can put it.
final _unsafeInName = RegExp(r'[\\/:*?"<>|]');

class ProjectExportSheet extends StatefulWidget {
  const ProjectExportSheet({super.key, required this.project});
  final ProjectMeta project;

  @override
  State<ProjectExportSheet> createState() => _ProjectExportSheetState();
}

class _ProjectExportSheetState extends State<ProjectExportSheet> {
  var _format = ExportFormat.docx;
  var _includeNotes = true;
  var _busy = false;
  String? _error;

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await exportProject(widget.project.id, _format, includeNotes: _includeNotes);
      final title = widget.project.displayTitle.replaceAll(_unsafeInName, '-').trim();
      final saved = await FilePicker.saveFile(
        fileName: '${title.isEmpty ? 'Export' : title}.${_format.extension}',
        bytes: bytes,
        mimeType: _format.mimeType,
        dialogTitle: 'Save the export',
      );
      // Cancelling the save dialog leaves the sheet up, choices intact.
      if (saved != null && mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText('The whole manuscript, chapters in reading order.', step: DsText.ui, color: Ds.low),
          const SizedBox(height: 18),
          const Eyebrow('Format'),
          const SizedBox(height: 10),
          for (final format in ExportFormat.values)
            _FormatRow(
              title: _formatLabels[format]!.$1,
              detail: _formatLabels[format]!.$2,
              selected: format == _format,
              onPressed: _busy ? null : () => setState(() => _format = format),
            ),
          const SizedBox(height: 14),
          Press(
            onPressed: _busy ? null : () => setState(() => _includeNotes = !_includeNotes),
            semanticLabel: 'Include notes',
            builder: (context, pressed) => SizedBox(
              height: DsGeom.row,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _includeNotes,
                      onChanged: _busy ? null : (v) => setState(() => _includeNotes = v ?? true),
                      activeColor: Ds.accent,
                      side: BorderSide(color: Ds.edgeHi),
                    ),
                  ),
                  const SizedBox(width: 10),
                  UiText('Include notes', step: DsText.ui, color: Ds.soft),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GkButton(label: 'Export', wide: true, busy: _busy, onPressed: _export),
          if (_error != null) ...[
            const SizedBox(height: 8),
            UiText(_error!, step: DsText.ui, color: Ds.destructive),
          ],
        ],
      ),
    );
  }
}

class _FormatRow extends StatelessWidget {
  const _FormatRow({required this.title, required this.detail, required this.selected, required this.onPressed});
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback? onPressed;

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
