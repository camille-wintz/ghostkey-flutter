import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/text.dart';
import 'empty_shelf_card.dart';
import 'folder_card.dart';
import 'new_novel_card.dart';
import 'new_novel_sheet.dart';
import 'project_card.dart';

/// The shelf: what is in the cloud root, drawn as books — a two-up grid of
/// covers, because an author picks the book they mean by recognising it.
/// Folders keep a row apiece above the grid, because a folder has no cover.
/// The grid's first cell is the book not written yet, as on the desk; an
/// author with no shelf at all gets one door instead.
class ShelfSection extends ConsumerWidget {
  const ShelfSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider);
    final projects = ref.watch(projectsProvider(null));
    // The series names under each title. Never awaited and never gating.
    final series = ref.watch(seriesByIdProvider).value;

    final error = folders.error ?? projects.error;
    final loading = folders.isLoading || projects.isLoading;
    final folderList = folders.value ?? const <Folder>[];
    final projectList = projects.value ?? const <ProjectMeta>[];
    final empty = !loading && folderList.isEmpty && projectList.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Eyebrow('Cloud'),
        ),
        if (error != null) ...[
          _Notice(messageFor(error)),
          _Grid(projects: const [], series: null, onOpen: (_) {}, onNew: () => showNewNovelSheet(context)),
        ] else if (loading && folderList.isEmpty && projectList.isEmpty)
          Row(
            children: [
              Expanded(child: NewNovelCard(onPressed: () => showNewNovelSheet(context))),
              const SizedBox(width: 16),
              const Expanded(child: ProjectCardSkeleton()),
            ],
          )
        else if (empty)
          EmptyShelfCard(onPressed: () => showNewNovelSheet(context))
        else ...[
          if (folderList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  for (final folder in folderList)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FolderCard(folder: folder),
                    ),
                ],
              ),
            ),
          _Grid(
            projects: projectList,
            series: series,
            onOpen: (project) => ref.read(activeProjectProvider.notifier).open(project),
            onNew: () => showNewNovelSheet(context),
          ),
        ],
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.projects, required this.series, required this.onOpen, required this.onNew});
  final List<ProjectMeta> projects;
  final Map<String, Series>? series;
  final ValueChanged<ProjectMeta> onOpen;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          // Two columns at 48% with the remaining 4% between them.
          final width = constraints.maxWidth * 0.48;
          return Wrap(
            spacing: constraints.maxWidth * 0.04,
            runSpacing: 20,
            children: [
              SizedBox(width: width, child: NewNovelCard(onPressed: onNew)),
              for (final project in projects)
                SizedBox(
                  width: width,
                  child: ProjectCard(
                    project: project,
                    series: seriesLabel(series, project.seriesId),
                    onPressed: () => onOpen(project),
                  ),
                ),
            ],
          );
        },
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: UiText(text, step: DsText.ui, color: Ds.mid, align: TextAlign.center),
      );
}
