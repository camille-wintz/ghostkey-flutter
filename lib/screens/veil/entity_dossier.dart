import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/button.dart';
import '../../ui/press.dart';
import '../../veil/dossier_build.dart';
import '../../veil/providers.dart';
import 'dossier_body.dart';
import 'veil_section.dart';

/// The entity's deep-dive dossier: generated server-side from the passages
/// around this entity's mentions, cached until a chapter that mentions it
/// changes. Cards carry no facts — this IS the entity's info surface — so
/// opening the page builds a missing dossier on its own; the button remains
/// as the retry after an error, the Update for a stale one, and the
/// Regenerate for a re-read.
class EntityDossier extends ConsumerStatefulWidget {
  const EntityDossier({
    super.key,
    required this.projectId,
    required this.entity,
    required this.dossier,
    required this.hasChapters,
  });

  final String projectId;
  final BibleEntity entity;
  final Dossier? dossier;
  final bool hasChapters;

  @override
  ConsumerState<EntityDossier> createState() => _EntityDossierState();
}

class _EntityDossierState extends ConsumerState<EntityDossier> {
  DossierTarget get _target => (projectId: widget.projectId, key: widget.entity.key);

  @override
  void initState() {
    super.initState();
    // After the first build, so the provider is being watched (and so kept
    // alive) by the time its notifier starts polling.
    Future<void>.microtask(() {
      if (mounted) unawaited(ref.read(dossierBuildProvider(_target).notifier).buildOnOpen());
    });
  }

  void _start({bool force = false}) => unawaited(ref.read(dossierBuildProvider(_target).notifier).start(force: force));

  @override
  Widget build(BuildContext context) {
    final build = ref.watch(dossierBuildProvider(_target));
    final probed = ref.watch(dossiersProvider(widget.projectId)).hasValue;
    final capability = ref.watch(capabilityProvider(dossierCapability));
    final dossier = widget.dossier;
    final canRun = capability.granted && widget.entity.mentionCount > 0 && widget.hasChapters;

    return VeilSection(
      title: 'Dossier',
      trailing: dossier != null && !build.building
          ? _RefreshLink(
              label: dossier.stale ? 'Update' : 'Regenerate',
              onTap: () => _start(force: !dossier.stale),
            )
          : null,
      child: switch ((build.building, build.error, dossier)) {
        (true, _, _) => _Working(build.progress),
        (false, final String error, _) => _Failed(error, canRun ? () => _start() : null),
        (false, null, final Dossier d) => DossierBody(dossier: d),
        (false, null, null) => Text(
            !probed
                ? 'Checking for a dossier…'
                : canRun
                    ? 'Reading the mentions…'
                    : _whyNot(capability),
            style: DsStyle.ui(DsText.ui, color: Ds.faint),
          ),
      },
    );
  }

  /// Why nothing will be built: the server's own checks, in its order.
  String _whyNot(CapabilityState capability) {
    if (!capability.granted) {
      final plan = capability.requiredPlan != null ? planName(capability.requiredPlan!) : 'a higher plan';
      return 'Writing a dossier is part of $plan. One already written reads on any plan.';
    }
    if (widget.entity.mentionCount == 0) {
      return 'No manuscript mentions to draw from yet — the dossier is written from the passages around each mention.';
    }
    return 'Needs a manuscript with chapters.';
  }
}

class _Working extends StatelessWidget {
  const _Working(this.progress);
  final String? progress;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent)),
          const SizedBox(width: 10),
          Expanded(child: Text(progress ?? 'Reading the mentions…', style: DsStyle.ui(DsText.ui, color: Ds.mid))),
        ],
      );
}

class _Failed extends StatelessWidget {
  const _Failed(this.error, this.onRetry);
  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error, style: DsStyle.ui(DsText.ui, color: Ds.destructive)),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GkButton(label: 'Retry the dossier', variant: ButtonVariant.outline, onPressed: onRetry),
            ),
        ],
      );
}

class _RefreshLink extends StatelessWidget {
  const _RefreshLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onTap,
        semanticLabel: label,
        builder: (context, pressed) => Opacity(
          opacity: pressed ? 0.7 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.refreshCw, size: 12, color: Ds.low),
              const SizedBox(width: 5),
              Text(label, style: DsStyle.ui(DsText.ui, color: Ds.low)),
            ],
          ),
        ),
      );
}
