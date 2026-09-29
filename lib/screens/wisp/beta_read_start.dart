import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../server/dto/wisp.dart';
import '../../ui/lock_notice.dart';
import '../../wisp/access.dart';
import '../../wisp/wisp_run.dart';

/// Ask a beta reader for their letter — or, [again], for a fresh read, which
/// is refused below `wisp.full_reports` as every analysis's re-run is. A
/// padlock answers with its notice; the phone never sells the plan.
void startBetaRead(BuildContext context, WidgetRef ref, String projectId, ReaderCard reader, {required bool again}) {
  final gate = ref.read(capabilityProvider(analysisCapability));
  final fullGate = ref.read(capabilityProvider(fullReportsCapability));
  if (!gate.granted) return explainLock(context, gate, 'Beta readers');
  if (again && !fullGate.granted) return explainLock(context, fullGate, fullReportsLabel);
  ref
      .read(wispRunProvider(analysisRunKey(projectId, reader.analysis)).notifier)
      .start({'analysis': reader.analysis, if (again) 'force': true});
}
