import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/orders.dart';

/// Stars, quick tags and an optional comment for a shop or technician.
Future<void> showReviewSheet(BuildContext context, {required String name, required String key}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(name: name, reviewKey: key),
    );

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.name, required this.reviewKey});

  final String name;
  final String reviewKey;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  var _stars = 0;
  final _tags = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final tags = [
      t.reviewTagGenuine,
      t.reviewTagFast,
      t.reviewTagPrice,
      t.reviewTagPolite,
      t.reviewTagOnTime,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.reviewTitle(widget.name),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: Space.md),
              StarPicker(value: _stars, onChanged: (v) => setState(() => _stars = v)),
              const SizedBox(height: Space.lg),
              Text(t.reviewTags, style: theme.textTheme.titleSmall),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final tag in tags)
                    FilterChip(
                      label: Text(tag),
                      selected: _tags.contains(tag),
                      onSelected: (v) => setState(() => v ? _tags.add(tag) : _tags.remove(tag)),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              TextField(maxLines: 3, decoration: InputDecoration(labelText: t.reviewComment)),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: _stars == 0
                    ? null
                    : () {
                        ref.read(reviewedProvider.notifier).add(widget.reviewKey);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(t.reviewThanks)));
                      },
                child: Text(t.reviewSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Demo controls" card: moves an order or booking one step forward.
class DemoControls extends StatelessWidget {
  const DemoControls({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        borderRadius: Radii.mdAll,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 20),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(t.demoControls, style: theme.textTheme.titleSmall)),
              const DemoBadge(),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(t.demoNextStepBody, style: theme.textTheme.bodySmall),
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.skip_next_outlined),
            label: Text(t.demoNextStep),
          ),
        ],
      ),
    );
  }
}
