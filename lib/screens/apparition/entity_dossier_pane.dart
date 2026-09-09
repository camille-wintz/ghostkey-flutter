import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/button.dart';
import '../../ui/press.dart';
import 'dossier_body.dart';
import 'entity_dossier_state.dart';
import 'providers.dart';

/// One name from the chapter's cast, opened: who they are, per the passages
/// that mention them.
///
/// The card itself holds no facts — a bible entity is a name and a list of
/// chapters — so this pane IS what an author tapped the name to read, and it
/// builds a missing dossier rather than offering a button that asks them to
/// confirm what they just asked for.
class EntityDossierPane extends ConsumerStatefulWidget {
  const EntityDossierPane({super.key, required this.projectId, required this.entity});
  final String projectId;
  final BibleEntity entity;

  @override
  ConsumerState<EntityDossierPane> createState() => _EntityDossierPaneState();
}

class _EntityDossierPaneState extends ConsumerState<EntityDossierPane> {
  late final EntityDossierState _state = EntityDossierState(
    projectId: widget.projectId,
    entityKey: widget.entity.key,
    probe: () => ref.read(dossiersProvider(widget.projectId).future),
    // A dossier already written stays readable on any plan; the capability
    // governs writing a new one.
    canBuild: () => ref.read(capabilityProvider('mara.entity_dossier')).granted,
    onFresh: () => ref.invalidate(dossiersProvider(widget.projectId)),
  );

  @override
  void initState() {
    super.initState();
    _state.open();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(capabilityProvider('mara.entity_dossier'));
    final chapters = widget.entity.chapters.length;
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final dossier = _state.dossier;
        final building = _state.building;
        final error = _state.error;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.entity.name, style: DsStyle.prose(DsText.title, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                chapters == 0
                    ? 'Not named in this book yet'
                    : 'In $chapters ${chapters == 1 ? 'chapter' : 'chapters'} of this book',
                style: DsStyle.ui(DsText.ui, color: Ds.low),
              ),
              const SizedBox(height: 20),
              if (dossier != null && dossier.stale && !building) ...[
                Press(
                  onPressed: () => _state.build(),
                  semanticLabel: 'Bring this dossier up to date',
                  builder: (context, pressed) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Ds.attentionMix(25)),
                      borderRadius: BorderRadius.circular(DsGeom.radius),
                      color: Ds.attentionMix(pressed ? 12 : 6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'A chapter this read has changed since it was written.',
                            style: DsStyle.ui(DsText.ui, color: Ds.attention300),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'UPDATE',
                          style: DsStyle.ui(DsText.ui, color: Ds.attention, weight: FontWeight.w600, tracking: DsTracking.control),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (building || _state.probing) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_state.progress ?? 'Reading the mentions…', style: DsStyle.ui(DsText.body, color: Ds.mid)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (error != null && !building) ...[
                Text(error, style: DsStyle.ui(DsText.body, color: Ds.mid)),
                if (capability.granted) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: GkButton(label: 'Try again', onPressed: () => _state.build())),
                ],
                const SizedBox(height: 20),
              ],
              if (!capability.granted && dossier == null) ...[
                Text(
                  '${capability.label ?? 'Entity dossiers'}'
                  '${capability.requiredPlan != null ? ' is part of ${planName(capability.requiredPlan!)}.' : ' is not part of your plan.'}',
                  style: DsStyle.ui(DsText.ui, color: Ds.faint),
                ),
                const SizedBox(height: 20),
              ],
              if (dossier != null) DossierBody(dossier: dossier),
              if (dossier != null && capability.granted && !building && !dossier.stale) ...[
                const SizedBox(height: 20),
                Press(
                  onPressed: () => _state.build(force: true),
                  semanticLabel: 'Rewrite this dossier from the current manuscript',
                  builder: (context, pressed) => Opacity(
                    opacity: pressed ? 0.6 : 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.rotateCcw, size: 13, color: Ds.faint),
                        const SizedBox(width: 8),
                        Text('Rewrite from the manuscript', style: DsStyle.ui(DsText.ui, color: Ds.faint)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
