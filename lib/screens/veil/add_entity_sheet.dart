import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../server/errors.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/sheet.dart';
import '../../ui/text.dart';
import '../../veil/entity_writes.dart';
import '../../veil/providers.dart';
import '../../veil/roster.dart';
import 'entity_screen.dart';
import 'veil_type_tab.dart';

/// The desk's New entity modal as a sheet: what it is, and its name. The
/// card opens as soon as it exists, where the rest — notes, appearance, the
/// GMC — is written the same way as on any other card.
///
/// [navigator] is the project's: the sheet's own context is gone by the
/// time the card is there to push.
Future<void> showAddEntitySheet(
  BuildContext context, {
  required String projectId,
  BibleEntityType type = BibleEntityType.character,
}) {
  final navigator = Navigator.of(context);
  return showGkSheet<void>(
    context,
    builder: (context) => _AddEntity(projectId: projectId, initialType: type, navigator: navigator),
  );
}

class _AddEntity extends ConsumerStatefulWidget {
  const _AddEntity({required this.projectId, required this.initialType, required this.navigator});
  final String projectId;
  final BibleEntityType initialType;
  final NavigatorState navigator;

  @override
  ConsumerState<_AddEntity> createState() => _AddEntityState();
}

class _AddEntityState extends ConsumerState<_AddEntity> {
  final _name = TextEditingController();
  late BibleEntityType _type = widget.initialType;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final card = await addEntity(ref, widget.projectId, type: _type, name: name);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (card != null) {
        widget.navigator.push(MaterialPageRoute<void>(builder: (_) => EntityScreen(entityKey: card.key)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _close() {
    if (!_saving) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final entities = ref.watch(bibleProvider(widget.projectId)).value?.entities ?? const <BibleEntity>[];
    return PopScope(
      canPop: !_saving,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(eyebrow: 'New entry', onClose: _close),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: ListenableBuilder(
                listenable: _name,
                builder: (context, _) {
                  final name = _name.text.trim();
                  final taken = entityAnsweringTo(entities, name);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Ds.void_,
                          border: Border.all(color: Ds.edge),
                          borderRadius: BorderRadius.circular(DsGeom.radius),
                        ),
                        child: Row(
                          children: [
                            for (final type in BibleEntityType.values)
                              Expanded(
                                child: VeilTypeTab(
                                  label: type.label,
                                  active: type == _type,
                                  empty: false,
                                  onTap: () => setState(() => _type = type),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GkField(
                        controller: _name,
                        placeholder: 'Name',
                        autofocus: true,
                        autocorrect: false,
                        enabled: !_saving,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => taken == null ? _add() : null,
                      ),
                      if (taken != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: UiText(
                            taken.hidden
                                ? '“${titleCase(taken.name)}” is in the hidden pile — unhide it from the roster.'
                                : 'The bible already has “${titleCase(taken.name)}”.',
                            step: DsText.ui,
                            color: Ds.attention,
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_error case final error?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: UiText(error, step: DsText.ui, color: Ds.destructive),
                        ),
                      GkButton(
                        label: 'Add ${_type.label.toLowerCase()}',
                        wide: true,
                        busy: _saving,
                        disabled: name.isEmpty || taken != null,
                        onPressed: _add,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
