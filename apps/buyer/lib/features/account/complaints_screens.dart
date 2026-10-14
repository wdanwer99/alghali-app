import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/account.dart';
import '../../widgets/buyer_widgets.dart';

String complaintCategory(BuildContext context, DisputeCategory c) {
  final t = context.t;
  return switch (c) {
    DisputeCategory.notReceived => t.complaintNotReceived,
    DisputeCategory.wrongPart => t.complaintWrongPart,
    DisputeCategory.damaged => t.complaintDamaged,
    DisputeCategory.notFitted => t.complaintNotFitted,
    DisputeCategory.payment => t.complaintPayment,
    DisputeCategory.behaviour => t.complaintBehaviour,
    DisputeCategory.other => t.complaintOther,
  };
}

String complaintStatus(BuildContext context, DisputeStatus s) {
  final t = context.t;
  return switch (s) {
    DisputeStatus.open => t.complaintOpen,
    DisputeStatus.inReview => t.complaintInReview,
    DisputeStatus.resolved => t.complaintResolved,
    DisputeStatus.rejected => t.complaintRejected,
  };
}

Tone _tone(DisputeStatus s) => switch (s) {
  DisputeStatus.open || DisputeStatus.inReview => Tone.warning,
  DisputeStatus.resolved => Tone.success,
  DisputeStatus.rejected => Tone.neutral,
};

/// "Report a problem" about a shop's part of an order or a fitting (D-105): our team, the
/// shop or technician and the buyer talk it through; money is put right from there.
Future<void> showComplaintSheet(BuildContext context, {String? subOrderId, String? bookingId}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComplaintSheet(subOrderId: subOrderId, bookingId: bookingId),
    );

class _ComplaintSheet extends ConsumerStatefulWidget {
  const _ComplaintSheet({this.subOrderId, this.bookingId});

  final String? subOrderId;
  final String? bookingId;

  @override
  ConsumerState<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends ConsumerState<_ComplaintSheet> {
  DisputeCategory? _category;
  final _text = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final c = _category;
    if (c == null || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final d = await ref
          .read(disputesProvider.notifier)
          .open(
            category: c,
            description: _text.text.trim(),
            subOrderId: widget.subOrderId,
            bookingId: widget.bookingId,
          );
      if (!mounted) return;
      Navigator.pop(context);
      await GoRouter.of(context).push(Routes.complaint(d.id));
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final categories = widget.bookingId != null
        ? const [
            DisputeCategory.notFitted,
            DisputeCategory.damaged,
            DisputeCategory.behaviour,
            DisputeCategory.payment,
            DisputeCategory.other,
          ]
        : const [
            DisputeCategory.notReceived,
            DisputeCategory.wrongPart,
            DisputeCategory.damaged,
            DisputeCategory.payment,
            DisputeCategory.behaviour,
            DisputeCategory.other,
          ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.complaintReport, style: theme.textTheme.titleLarge),
              const SizedBox(height: Space.sm),
              Text(t.complaintIntro, style: theme.textTheme.bodySmall),
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(complaintCategory(context, c)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: t.complaintDescribe),
              ),
              const SizedBox(height: Space.md),
              FilledButton(
                onPressed: _sending || _category == null || _text.text.trim().isEmpty
                    ? null
                    : _send,
                child: Text(t.complaintSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The buyer's complaints.
class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.complaintsTitle)),
      body: AsyncBody(
        value: ref.watch(disputesProvider),
        onRefresh: () => ref.read(disputesProvider.notifier).refresh(),
        data: (list) => list.isEmpty
            ? ListView(
                children: [
                  EmptyState(
                    icon: Icons.support_agent_outlined,
                    title: t.complaintsEmpty,
                    message: t.complaintsEmptyBody,
                  ),
                ],
              )
            : ListView.separated(
                padding: Space.pageInsets,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (context, i) {
                  final d = list[i];
                  return TapCard(
                    onTap: () => context.push(Routes.complaint(d.id)),
                    child: Row(
                      children: [
                        const IconTile(icon: Icons.support_agent_outlined),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaintCategory(context, d.category),
                                style: theme.textTheme.titleSmall,
                              ),
                              Text(
                                [
                                  if (d.ref != null) formatRef(d.ref!),
                                  context.date(d.createdAt),
                                ].join(' · '),
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: Space.xs),
                              StatusPill(
                                label: complaintStatus(context, d.status),
                                tone: _tone(d.status),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// One complaint: what the buyer wrote, the replies, and a box to answer.
class ComplaintScreen extends ConsumerStatefulWidget {
  const ComplaintScreen({super.key, required this.disputeId});

  final String disputeId;

  @override
  ConsumerState<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends ConsumerState<ComplaintScreen> {
  final _reply = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(disputesProvider.notifier).reply(widget.disputeId, _reply.text.trim());
      _reply.clear();
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final list = ref.watch(disputesProvider);
    final d = list.value?.where((x) => x.id == widget.disputeId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(t.complaintTitle)),
      body: d == null
          ? AsyncBody(
              value: list,
              onRefresh: () => ref.read(disputesProvider.notifier).refresh(),
              data: (_) => ListView(
                children: [
                  EmptyState(icon: Icons.support_agent_outlined, title: context.core.errNotFound),
                ],
              ),
            )
          : ListView(
              padding: Space.pageInsets,
              children: [
                SectionCard(
                  title: complaintCategory(context, d.category),
                  trailing: StatusPill(
                    label: complaintStatus(context, d.status),
                    tone: _tone(d.status),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(d.description, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: Space.xs),
                      Text(context.dayTime(d.createdAt), style: theme.textTheme.bodySmall),
                      if (d.resolution != null) ...[
                        const SizedBox(height: Space.md),
                        InfoBanner(
                          tone: Tone.success,
                          title: t.complaintOutcome,
                          message: d.resolution!,
                        ),
                      ],
                    ],
                  ),
                ),
                for (final m in d.messages) ...[
                  const SizedBox(height: Space.sm),
                  Align(
                    alignment: m.mine
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: Card(
                      color: m.mine ? theme.colorScheme.secondaryContainer : null,
                      child: Padding(
                        padding: const EdgeInsets.all(Space.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.mine
                                  ? t.complaintYou
                                  : m.fromAdmin
                                  ? t.complaintTeam
                                  : m.sender ?? '',
                              style: theme.textTheme.labelMedium,
                            ),
                            Text(m.body, style: theme.textTheme.bodyMedium),
                            Text(context.dayTime(m.at), style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (!d.closed) ...[
                  const SizedBox(height: Space.lg),
                  TextField(
                    controller: _reply,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: t.complaintReply,
                      suffixIcon: IconButton(
                        tooltip: t.chatSend,
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
