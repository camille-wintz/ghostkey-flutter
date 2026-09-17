import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../chat/quota_feature.dart';
import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/sheet.dart';
import '../../wisp/access.dart';
import '../../wisp/line_edit.dart';
import 'wisp_lock.dart';

/// Ask for a line edit on one chapter: what this pass should watch for, if
/// anything, and Run. The model is the server's default — the desk's picker
/// is not carried here.
Future<void> showLineEditSheet(BuildContext context, {required String projectId, required DocumentSummary chapter}) {
  final container = ProviderScope.containerOf(context);
  final gate = container.read(capabilityProvider(lineEditCapability));
  if (!gate.granted) {
    explainWispLock(context, gate, 'Line editing');
    return Future.value();
  }
  return showGkSheet<void>(
    context,
    header: SheetHeader(eyebrow: 'Line edit', onClose: () => Navigator.of(context).pop()),
    builder: (context) => _LineEditForm(projectId: projectId, chapter: chapter),
  );
}

class _LineEditForm extends ConsumerStatefulWidget {
  const _LineEditForm({required this.projectId, required this.chapter});
  final String projectId;
  final DocumentSummary chapter;

  @override
  ConsumerState<_LineEditForm> createState() => _LineEditFormState();
}

class _LineEditFormState extends ConsumerState<_LineEditForm> {
  final _focus = TextEditingController();
  bool _pending = false;
  String? _failure;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _pending = true;
      _failure = null;
    });
    try {
      await startLineEdit(ref, widget.projectId, widget.chapter.id, _focus.text);
      ref.invalidate(quotaProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _failure = "The pass couldn't start: ${messageFor(e)}");
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quota = quotaLine(ref.watch(quotaProvider).value?.feature(lineEditQuotaFeature));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.chapter.label, style: DsStyle.prose(const DsStep(20, 26), color: Ds.hi)),
          const SizedBox(height: 18),
          Text('FOCUS — OPTIONAL', style: DsStyle.eyebrow(weight: FontWeight.w600)),
          const SizedBox(height: 8),
          GkField(
            controller: _focus,
            placeholder: 'e.g. the dialogue in the second half',
            enabled: !_pending,
            textInputAction: TextInputAction.done,
          ),
          if (_failure case final failure?) ...[
            const SizedBox(height: 10),
            Text(failure, style: DsStyle.ui(DsText.ui, color: Ds.destructive)),
          ],
          const SizedBox(height: 18),
          GkButton(label: 'Run', wide: true, busy: _pending, onPressed: _run),
          if (quota != null) ...[
            const SizedBox(height: 10),
            Text(quota, textAlign: TextAlign.center, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
          ],
        ],
      ),
    );
  }
}
