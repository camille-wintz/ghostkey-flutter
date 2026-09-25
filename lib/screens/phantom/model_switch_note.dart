import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/models.dart';
import '../../chat/turn.dart';
import '../../ds/tokens.dart';
import '../../server/providers.dart';

/// One quiet line under an answer another model gave, because the picked one
/// can't see a picture the turn looked at. The desk names the model on every
/// turn; the phone only when it is not the one the author picked.
class ModelSwitchNote extends ConsumerWidget {
  const ModelSwitchNote({super.key, required this.modelSwitch});
  final ModelSwitch modelSwitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(modelCatalogProvider).value;
    final answered = modelName(catalog, modelSwitch.model);
    final picked = modelName(catalog, modelSwitch.from);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        "$answered answered — $picked can't see pictures.",
        style: DsStyle.ui(DsText.ui, color: Ds.low),
      ),
    );
  }
}
