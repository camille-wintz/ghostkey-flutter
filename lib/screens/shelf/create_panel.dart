import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/text.dart';

/// Where a book starts: typed, or handed over as a Word document. The two
/// live in one panel because they are one decision — this is the shelf's
/// answer to "I have nothing here yet" — and the desk offers exactly this
/// pair in exactly this order.
class CreatePanel extends StatelessWidget {
  const CreatePanel({
    super.key,
    required this.name,
    required this.onCreate,
    required this.creating,
    required this.onImport,
    required this.importing,
    required this.importStatus,
  });
  final TextEditingController name;
  final VoidCallback onCreate;
  final bool creating;
  final VoidCallback onImport;
  final bool importing;

  /// What the import is doing right now, or null when nothing is going. The
  /// line matters: a hundred-chapter manuscript is minutes of a spinner
  /// otherwise, and a spinner that long reads as a hang.
  final String? importStatus;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: ListenableBuilder(
          listenable: name,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GkField(
                controller: name,
                placeholder: 'Project name...',
                autocorrect: false,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => onCreate(),
              ),
              const SizedBox(height: 12),
              GkButton(
                label: 'Create',
                wide: true,
                busy: creating,
                disabled: name.text.trim().isEmpty || importing,
                onPressed: onCreate,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: _Or(),
              ),
              GkButton(
                label: 'Import DOCX',
                variant: ButtonVariant.outline,
                wide: true,
                busy: importing,
                disabled: creating,
                onPressed: onImport,
              ),
              if (importStatus != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: UiText(
                    importStatus!,
                    step: DsText.ui,
                    color: Ds.low,
                    align: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      );
}

/// The desk's own divider between the two ways in.
class _Or extends StatelessWidget {
  const _Or();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Container(height: 1, color: Ds.edge)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: UiText('or', step: DsText.ui, color: Ds.low),
          ),
          Expanded(child: Container(height: 1, color: Ds.edge)),
        ],
      );
}
