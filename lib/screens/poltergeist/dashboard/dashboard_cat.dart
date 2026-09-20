import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../ds/tokens.dart';
import '../../../poltergeist/providers.dart';
import '../../../poltergeist/time.dart';
import '../../../rewards/cat_picture.dart';
import '../poltergeist_tabs.dart';
import '../section_link.dart';
import 'dashboard_section.dart';

/// The newest cat on the author's shelf, or — before the first — a cat's
/// shape and how one is earned. Both stand in the same framed tile, so the
/// first cat arrives in the frame that has been waiting for it rather than
/// replacing a loose shape with a picture.
class DashboardCat extends ConsumerWidget {
  const DashboardCat({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(catsProvider);
    final latest = cats.value?.firstOrNull;
    final placeholder = ref.watch(catCatalogueProvider).value?.firstOrNull;

    return DashboardSection(
      eyebrow: 'Latest cat',
      action: SectionLink('All cats →', onPressed: () => PoltergeistTabs.of(context).open(PoltergeistTab.cats)),
      child: !cats.hasValue
          ? const SectionNote('Loading…')
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Ds.panel,
                    borderRadius: BorderRadius.circular(DsGeom.radius),
                    border: Border.all(color: Ds.edge),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: latest != null
                      ? CatPicture(latest)
                      // The shape cut from the step above the tile: a cat you
                      // can just make out, with its coat and its name kept back.
                      : placeholder == null
                          ? null
                          : SvgPicture.string(
                              placeholder.silhouette,
                              colorFilter: ColorFilter.mode(Ds.surf, BlendMode.srcIn),
                              semanticsLabel: 'A cat still to earn',
                            ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: latest == null
                      ? Text(
                          'Write for seven days to earn a cat.',
                          style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              latest.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsStyle.prose(const DsStep(19, 26), color: Ds.hi),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dayLabel(latest.earnedAt.substring(0, 10)),
                              style: DsStyle.ui(DsText.eyebrow, color: Ds.faint),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
