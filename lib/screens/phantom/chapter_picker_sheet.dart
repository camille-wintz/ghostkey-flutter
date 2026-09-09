import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/providers.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import '../../ui/sheet.dart';

/// The project's chapter tree — folders as section headers — with word
/// counts from the listing, so no body is fetched to draw a number. Resolves
/// with the picked chapter, or null when dismissed.
Future<DocumentSummary?> showChapterPickerSheet(
  BuildContext context, {
  required String projectId,
  required Set<String> attachedDocumentIds,
}) =>
    showGkSheet<DocumentSummary>(
      context,
      header: SheetHeader(eyebrow: 'Attach a chapter', onClose: () => Navigator.of(context).pop()),
      builder: (context) => _PickerList(projectId: projectId, attached: attachedDocumentIds),
    );

/// One drawn row of the picker: a folder heading, or a chapter under one.
sealed class _Item {
  const _Item();
}

class _FolderItem extends _Item {
  const _FolderItem(this.name);
  final String name;
}

class _ChapterItem extends _Item {
  const _ChapterItem(this.doc, {required this.indent});
  final DocumentSummary doc;
  final bool indent;
}

List<_Item> _flatten(List<ChaptersListEntry> tree) => [
      for (final entry in tree)
        ...switch (entry) {
          DocumentSummary() => [_ChapterItem(entry, indent: false)],
          ChapterGroup() => [
              _FolderItem(entry.name),
              for (final doc in entry.chapters) _ChapterItem(doc, indent: true),
            ],
        },
    ];

String _wordsLabel(DocumentSummary doc) => switch (doc.wordCount) {
      null => '',
      0 => 'empty',
      final n => '${formatWords(n)} words',
    };

class _PickerList extends ConsumerWidget {
  const _PickerList({required this.projectId, required this.attached});
  final String projectId;
  final Set<String> attached;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(projectProvider(projectId)).value?.chapters ?? const [];
    final items = _flatten(tree);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: UiText('No chapters yet.', step: DsText.ui, color: Ds.mid),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: items.length,
      itemBuilder: (context, i) => switch (items[i]) {
        _FolderItem(:final name) => _FolderHeading(name: name),
        _ChapterItem(:final doc, :final indent) => _ChapterRow(
            doc: doc,
            indent: indent,
            attached: attached.contains(doc.id),
            onPressed: () => Navigator.of(context).pop(doc),
          ),
      },
    );
  }
}

class _FolderHeading extends StatelessWidget {
  const _FolderHeading({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(LucideIcons.folder, size: 15, color: Ds.mid),
              const SizedBox(width: 8),
              Expanded(child: UiText(name, step: DsText.ui, color: Ds.mid, maxLines: 1)),
            ],
          ),
        ),
      );
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.doc, required this.indent, required this.attached, required this.onPressed});
  final DocumentSummary doc;
  final bool indent;

  /// Already attached — listed, but not pickable twice.
  final bool attached;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        enabled: !attached,
        semanticLabel: doc.label,
        builder: (context, pressed) => Container(
          height: 44,
          padding: EdgeInsets.only(left: indent ? 30 : 18, right: 18),
          color: pressed ? Ds.veil : const Color(0x00000000),
          child: Row(
            children: [
              Expanded(child: UiText(doc.label, color: attached ? Ds.faint : Ds.soft, maxLines: 1)),
              const SizedBox(width: 10),
              UiText(attached ? 'attached' : _wordsLabel(doc), step: DsText.eyebrow, color: Ds.faint),
              if (attached) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.check, size: 14, color: Ds.faint),
              ],
            ],
          ),
        ),
      );
}
