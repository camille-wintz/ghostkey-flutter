import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../autosave/field_autosave.dart';
import '../server/plan/api.dart';
import 'providers.dart';

/// The outline's prose as a field that saves itself — the one way the Outline
/// page and the chat's review write it. The text goes alone (the PUT is
/// partial), so a proposal being reviewed elsewhere is left to the server's
/// rule. Takes the container: the last keystroke is flushed as the page goes.
FieldAutosave outlineAutosave(ProviderContainer container, String projectId, String initial) => FieldAutosave(
      initial: initial,
      save: (text) async {
        await putAuthoredOutlineText(projectId, text);
        container.invalidate(authoredOutlineProvider(projectId));
      },
    );
