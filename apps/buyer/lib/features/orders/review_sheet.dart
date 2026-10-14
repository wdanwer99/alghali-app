import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/account.dart';

/// Stars, quick tags and an optional comment for a shop (a received [subOrderId]) or a
/// technician (a finished [bookingId]) (D-105). Sent through the outbox, so it also works
/// offline; rating again within 30 days changes the review.
Future<void> showReviewSheet(
  BuildContext context, {
  required String name,
  String? subOrderId,
  String? bookingId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ReviewSheet(name: name, subOrderId: subOrderId, bookingId: bookingId),
);

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.name, this.subOrderId, this.bookingId});

  final String name;
  final String? subOrderId;
  final String? bookingId;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  var _stars = 0;
  final _tags = <String>{};
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final comment = [..._tags, _comment.text.trim()].where((s) => s.isNotEmpty).join(' · ');
    final messenger = ScaffoldMessenger.of(context);
    final thanks = context.t.reviewThanks;
    Navigator.pop(context);
    await ref
        .read(reviewedProvider.notifier)
        .rate(
          stars: _stars,
          comment: comment,
          subOrderId: widget.subOrderId,
          bookingId: widget.bookingId,
        );
    messenger.showSnackBar(SnackBar(content: Text(thanks)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final tags = widget.bookingId != null
        ? [t.reviewTagOnTime, t.reviewTagPolite, t.reviewTagPrice, t.reviewTagFast]
        : [t.reviewTagGenuine, t.reviewTagFast, t.reviewTagPrice, t.reviewTagPolite];
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
              TextField(
                controller: _comment,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(labelText: t.reviewComment),
              ),
              const SizedBox(height: Space.lg),
              FilledButton(onPressed: _stars == 0 ? null : _submit, child: Text(t.reviewSubmit)),
            ],
          ),
        ),
      ),
    );
  }
}
