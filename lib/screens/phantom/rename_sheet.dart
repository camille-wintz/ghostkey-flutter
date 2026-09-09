import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/text.dart';

/// A rename card with its own field. Resolves with the trimmed new title, or
/// null when cancelled or left empty.
Future<String?> showRenameSheet(BuildContext context, {required String title}) => showDialog<String>(
      context: context,
      barrierColor: const Color(0xC708060D),
      builder: (context) => _RenameCard(title: title),
    );

class _RenameCard extends StatefulWidget {
  const _RenameCard({required this.title});
  final String title;

  @override
  State<_RenameCard> createState() => _RenameCardState();
}

class _RenameCardState extends State<_RenameCard> {
  late final TextEditingController _controller = TextEditingController(text: widget.title)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.title.length);

  String get _trimmed => _controller.text.trim();

  void _submit() {
    if (_trimmed.isEmpty) return;
    Navigator.of(context).pop(_trimmed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: const Color(0x00000000),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Ds.panel,
            border: Border.all(color: Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandTitle('Rename chat', size: BrandTitleSize.chrome),
              const SizedBox(height: 12),
              GkField(
                controller: _controller,
                placeholder: 'Chat title',
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GkButton(label: 'Cancel', variant: ButtonVariant.outline, onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  GkButton(label: 'Save', disabled: _trimmed.isEmpty, onPressed: _submit),
                ],
              ),
            ],
          ),
        ),
      );
}
