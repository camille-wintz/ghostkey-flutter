import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mara/providers.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';
import '../../project/project_root.dart';
import '../mara_page_frame.dart';
import 'outline_page_body.dart';

/// The Outline: the book's plan in the author's prose. Read once as the page
/// opens; the editor is theirs from then on.
class OutlinePage extends ConsumerWidget {
  const OutlinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final outline = ref.watch(authoredOutlineProvider(projectId));
    if (outline.value case final value?) return OutlinePageBody(projectId: projectId, initial: value.text);
    return MaraPageFrame(
      title: 'Outline',
      child: outline.hasError
          ? StateScreen(
              message: "Couldn't read the outline",
              detail: messageFor(outline.error),
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(authoredOutlineProvider(projectId)),
            )
          : const StateScreen(spinner: true, message: 'Reading the outline…'),
    );
  }
}
