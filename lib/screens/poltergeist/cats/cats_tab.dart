import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../poltergeist/providers.dart';
import '../../../poltergeist/time.dart';
import '../../../rewards/cat_picture.dart';
import '../../../server/dto/rewards.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';

/// The author's cats, newest first — one card each, the design's collectible
/// frame. The shelf is the author's, not the book's: a cat earned in another
/// book sits here too. The empty state says how the first one is earned.
class CatsTab extends ConsumerWidget {
  const CatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(catsProvider);
    final list = cats.value;

    if (list == null) {
      if (cats.hasError) {
        return StateScreen(
          message: "The shelf didn't load.",
          detail: messageFor(cats.error),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(catsProvider),
        );
      }
      return const StateScreen(spinner: true, message: 'Looking under the desk…');
    }
    if (list.isEmpty) {
      return const StateScreen(
        message: 'No cats yet.',
        detail: 'Set a daily target on the words page, reach it on five days of a week, and one turns up here.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) => _CatCard(list[i]),
    );
  }
}

class _CatCard extends StatelessWidget {
  const _CatCard(this.cat);
  final Cat cat;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Ds.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Ds.edge),
              ),
              padding: const EdgeInsets.all(16),
              child: CatPicture(cat),
            ),
          ),
          const SizedBox(height: 10),
          Text('COLLECTIBLE', style: DsStyle.eyebrow()),
          const SizedBox(height: 4),
          Text(
            cat.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsStyle.prose(const DsStep(18, 24), color: Ds.hi),
          ),
          const SizedBox(height: 2),
          Text(dayLabel(cat.earnedAt.substring(0, 10)), style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
        ],
      );
}
