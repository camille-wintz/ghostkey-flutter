import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/projects/covers.dart';
import '../../ui/press.dart';

/// A book on the shelf: its cover at a book's proportions, then title, author
/// and series. A project with no cover draws the same frame around a book
/// glyph, so the grid stays a grid.
class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.series, required this.onPressed});
  final ProjectMeta project;
  final String? series;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final url = projectThumbnailUrl(project);
    return Press(
      onPressed: onPressed,
      semanticLabel: project.displayTitle,
      builder: (context, pressed) => Opacity(
        opacity: pressed ? 0.7 : 1,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Ds.surf,
                  border: Border.all(color: Ds.edge),
                  borderRadius: BorderRadius.circular(DsGeom.radius),
                ),
                clipBehavior: Clip.antiAlias,
                child: url != null
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, _) => _Glyph(),
                      )
                    : _Glyph(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              project.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DsStyle.ui(const DsStep(15, 20), color: Ds.hi, weight: FontWeight.w600),
            ),
            if (project.author.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  project.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DsStyle.ui(DsText.ui, color: Ds.mid),
                ),
              ),
            if (series != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  series!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Icon(LucideIcons.bookOpen, size: 24, color: Ds.accent));
}

/// A book-shaped hole while the shelf loads.
class ProjectCardSkeleton extends StatelessWidget {
  const ProjectCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Ds.surf,
                border: Border.all(color: Ds.edge),
                borderRadius: BorderRadius.circular(DsGeom.radius),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FractionallySizedBox(
            widthFactor: 0.7,
            child: Container(height: 12, decoration: BoxDecoration(color: Ds.raise, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 6),
          FractionallySizedBox(
            widthFactor: 0.45,
            child: Container(height: 9, decoration: BoxDecoration(color: Ds.raise, borderRadius: BorderRadius.circular(4))),
          ),
        ],
      );
}
