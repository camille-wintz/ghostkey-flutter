import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/press.dart';
import '../../ui/sheet.dart';
import '../../ui/text.dart';

/// A folder above the shelf. It borrows the design's list row rather than
/// inventing a third shape: folders read as a different kind of thing than
/// the grid below them, which is what they are. Tapping one opens its books
/// in a sheet — a phone's shelf stays one screen.
class FolderCard extends ConsumerWidget {
  const FolderCard({super.key, required this.folder});
  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Press(
        onPressed: () => showGkSheet<void>(
          context,
          header: SheetHeader(eyebrow: folder.name, onClose: () => Navigator.of(context).pop()),
          builder: (context) => _FolderBooks(folderId: folder.id),
        ),
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: pressed ? Ds.surf : Ds.panel,
            border: Border.all(color: Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Ds.surf,
                  border: Border.all(color: Ds.edge),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(LucideIcons.folder, size: 16, color: Ds.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsStyle.ui(const DsStep(15, 20), color: Ds.hi, weight: FontWeight.w600),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 15, color: Ds.faint),
            ],
          ),
        ),
      );
}

class _FolderBooks extends ConsumerWidget {
  const _FolderBooks({required this.folderId});
  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider(folderId));
    return projects.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: UiText(e.toString(), color: Ds.mid)),
      data: (list) => list.isEmpty
          ? Padding(padding: const EdgeInsets.all(24), child: UiText('Nothing in this folder yet.', color: Ds.mid))
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                for (final project in list)
                  Press(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(activeProjectProvider.notifier).open(project.id);
                    },
                    builder: (context, pressed) => Container(
                      height: DsGeom.row,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: pressed ? Ds.veil : const Color(0x00000000),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        project.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsStyle.ui(DsText.body, color: Ds.soft),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
