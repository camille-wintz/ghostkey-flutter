import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/dates.dart';
import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/projects/covers.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import 'project_backdrop.dart';
import 'project_cover.dart';

/// The project home's stage: the backdrop its cover lights, the way back to
/// the shelf, and the book held above the fold with its title — everything on
/// the home except the rooms, which are [below].
///
/// It is its own widget because a book opens on it twice. While the project
/// loads, `ProjectRoot` draws it from the shelf's summary with a quiet
/// indicator under the book; once it lands, the home draws it again with the
/// rooms. Both draw the same pixels, so the cover is the loading screen and
/// arriving only adds the rooms.
class ProjectStage extends StatelessWidget {
  const ProjectStage({
    super.key,
    required this.project,
    required this.onHome,
    required this.below,
    this.coverUrl,
    this.onSettings,
    this.onExport,
    this.onOpenBook,
  });

  final ProjectMeta? project;
  final VoidCallback onHome;
  final Widget below;

  /// The full-size cover, once the project's assets have said which one it
  /// is. The shelf's thumbnail stands in until then, and under it after.
  final String? coverUrl;

  /// Opens the project's settings. Absent while the project is still loading,
  /// when there is nothing yet to edit.
  final VoidCallback? onSettings;

  /// Opens the export sheet. Absent while the project is still loading.
  final VoidCallback? onExport;

  /// The book itself is a door to Apparition, as on the desktop. Absent while
  /// the project loads, and when the plan locks the room — then it stays a
  /// book to look at, and Apparition's own row explains the lock.
  final VoidCallback? onOpenBook;

  @override
  Widget build(BuildContext context) {
    final project = this.project;
    final title = project?.displayTitle ?? 'Project';
    final edited = project != null ? formatShortDate(project.updatedAt) : '';

    // The SafeArea below deliberately lets the backdrop run under the gesture
    // bar, so the scroll has to reserve that inset itself or the last room row
    // ends up sitting on it.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Ds.void_,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ProjectBackdrop(backdropUrl: project != null ? projectBackdropUrl(project) : null),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Press(
                          onPressed: onHome,
                          semanticLabel: 'Back to Home',
                          builder: (context, pressed) => Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: pressed ? Ds.veil : const Color(0x00000000),
                              borderRadius: BorderRadius.circular(DsGeom.radius),
                            ),
                            child: Icon(LucideIcons.chevronLeft, size: 17, color: Ds.mid),
                          ),
                        ),
                        const Spacer(),
                        if (onExport != null)
                          _BarLink(icon: LucideIcons.download, label: 'Export', onPressed: onExport!),
                        if (onSettings != null)
                          _BarLink(icon: LucideIcons.settings, label: 'Project settings', onPressed: onSettings!),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RepaintBoundary(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 36 + bottomInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 30),
                            child: Center(
                              child: _BookDoor(
                                onOpen: onOpenBook,
                                child: ProjectCover(
                                  coverUrl: coverUrl,
                                  thumbnailUrl: project != null ? projectThumbnailUrl(project) : null,
                                  title: title,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Amber means attention, and what this row is drawing
                              // attention to is which of an author's books they are inside.
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Ds.attention,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Ds.attention, blurRadius: 10)],
                                ),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                'CURRENT PROJECT',
                                style: DsStyle.ui(
                                  DsText.eyebrow,
                                  color: Ds.mid,
                                  weight: FontWeight.w600,
                                  tracking: 11 * 0.32,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          Text(
                            title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: DsStyle.prose(
                              const DsStep(30, 33),
                              weight: FontWeight.w600,
                            ).copyWith(letterSpacing: -0.15),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            project?.author.isNotEmpty == true ? project!.author : 'Unassigned author',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: DsStyle.ui(const DsStep(19, 22), color: Ds.soft),
                          ),
                          if (edited.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Center(child: _Chip('Last edited $edited')),
                            ),
                          const SizedBox(height: 30),
                          below,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The cover as a press when it opens something; the cover alone otherwise.
/// Pressed, the book sinks a little — it floats and tilts, so a fill behind
/// it would show nothing.
class _BookDoor extends StatelessWidget {
  const _BookDoor({required this.onOpen, required this.child});
  final VoidCallback? onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onOpen == null) return child;
    return Press(
      onPressed: onOpen,
      semanticLabel: 'Open in Apparition',
      builder: (context, pressed) => AnimatedScale(
        scale: pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 140),
        child: child,
      ),
    );
  }
}

/// A quiet labelled action in the stage's top bar.
class _BarLink extends StatelessWidget {
  const _BarLink({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed) => Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Ds.mid),
              const SizedBox(width: 6),
              UiText(label, color: Ds.mid),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Ds.veil,
      border: Border.all(color: Ds.edge),
      borderRadius: BorderRadius.circular(DsGeom.radius),
    ),
    child: UiText(text, step: DsText.ui, color: Ds.soft),
  );
}
