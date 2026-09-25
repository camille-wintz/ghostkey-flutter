import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/review/providers.dart';
import '../../../server/errors.dart';
import '../../../ui/picture_page.dart';
import '../../../ui/state_screen.dart';
import '../../../veil/providers.dart';

/// A library picture a tool opened beside the conversation, fitted and
/// pinch-zoomable, its caption beneath. The view names only the item, so the
/// item is read for its bytes. Display only.
class ImageReview extends ConsumerWidget {
  const ImageReview({super.key, required this.projectId, required this.itemId, this.headerTitle});
  final String projectId;
  final String itemId;

  /// What the bar above already says, so the page does not say it twice.
  final String? headerTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (projectId: projectId, itemId: itemId);
    return ref.watch(mediaItemProvider(key)).when(
          skipLoadingOnReload: true,
          loading: () => const StateScreen(spinner: true, message: 'Opening the picture…'),
          error: (e, _) => StateScreen(
            message: 'The picture would not open',
            detail: messageFor(e),
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(mediaItemProvider(key)),
          ),
          data: (item) {
            final url = seriesAssetUrl(item.seriesId, item.assetId);
            if (!item.isImage || url == null) return const StateScreen(message: 'This picture is gone');
            return PicturePage(
              url: url,
              title: item.title.trim() == headerTitle?.trim() ? '' : item.title,
              caption: item.body,
            );
          },
        );
  }
}
