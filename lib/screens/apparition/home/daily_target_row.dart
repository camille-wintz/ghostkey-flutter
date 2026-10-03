import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../rewards/providers.dart';
import '../../../server/rewards/api.dart';
import '../../../ui/field.dart';

/// The words a day the author aims for, set in place under the chart. One
/// target for the account: every book's words count towards it, so the line
/// under the label says how today stands across all of them. Saves on submit;
/// an emptied field clears the target. The server answers back through the
/// rewards read, so the field follows it.
class DailyTargetRow extends ConsumerStatefulWidget {
  const DailyTargetRow({super.key, required this.target, required this.writtenToday});
  final int? target;
  final int writtenToday;

  @override
  ConsumerState<DailyTargetRow> createState() => _DailyTargetRowState();
}

class _DailyTargetRowState extends ConsumerState<DailyTargetRow> {
  late final TextEditingController _controller = TextEditingController(text: _text(widget.target));
  bool _saving = false;

  static String _text(int? target) => target == null ? '' : '$target';

  @override
  void didUpdateWidget(DailyTargetRow old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) _controller.text = _text(widget.target);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _commit(String raw) async {
    final trimmed = raw.trim();
    final next = trimmed.isEmpty ? null : int.tryParse(trimmed);
    if (trimmed.isNotEmpty && (next == null || next < 1)) {
      _controller.text = _text(widget.target);
      return;
    }
    if (next == widget.target) return;
    setState(() => _saving = true);
    try {
      await setMyDailyTarget(next);
      ref.invalidate(rewardsProvider);
    } catch (e) {
      debugPrint('[rewards] daily target save failed: $e');
      _controller.text = _text(widget.target);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _acrossBooks => widget.target == null
      ? 'Across all your books'
      : '${formatWords(widget.writtenToday)} of ${formatWords(widget.target!)} today, across all your books';

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY TARGET', style: DsStyle.eyebrow()),
                const SizedBox(height: 4),
                Text(_acrossBooks, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: GkField(
              controller: _controller,
              placeholder: '—',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              enabled: !_saving,
              onSubmitted: _commit,
            ),
          ),
        ],
      );
}
