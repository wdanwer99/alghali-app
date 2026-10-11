import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/orders.dart';
import '../../widgets/buyer_widgets.dart';

/// Bankak confirmed transfer: amount, account, order number to type in the
/// note, then the receipt and/or transaction number. An admin confirms it
/// against the bank statement; the screenshot alone never marks it paid.
class BankakScreen extends ConsumerStatefulWidget {
  const BankakScreen({super.key, required this.id, this.isBooking = false});

  final String id;
  final bool isBooking;

  @override
  ConsumerState<BankakScreen> createState() => _BankakScreenState();
}

class _BankakScreenState extends ConsumerState<BankakScreen> {
  final _txn = TextEditingController();
  var _receipt = false;
  var _sending = false;
  var _showError = false;

  @override
  void dispose() {
    _txn.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_receipt && _txn.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    if (widget.isBooking) {
      ref.read(bookingsProvider.notifier).submitReceipt(widget.id);
      context.pushReplacement(Routes.booking(widget.id));
    } else {
      ref.read(ordersProvider.notifier).submitReceipt(widget.id, txnNo: _txn.text.trim());
      context.pushReplacement(Routes.order(widget.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final settings = ref.watch(platformSettingsProvider);

    final (amount, ref_, payBy, status) = widget.isBooking
        ? switch (ref.watch(bookingsProvider).where((b) => b.id == widget.id).firstOrNull) {
            final b? => (
              b.bankakDueSdg,
              b.ref,
              b.events.first.at.add(Duration(minutes: settings.paymentWindowMinutes)),
              b.paymentStatus,
            ),
            null => (0, '', DateTime.now(), null),
          }
        : switch (ref.watch(ordersProvider).where((o) => o.id == widget.id).firstOrNull) {
            final o? => (o.bankakDueSdg, o.ref, o.payBy, o.paymentStatus),
            null => (0, '', DateTime.now(), null),
          };
    final details = widget.isBooking ? Routes.booking(widget.id) : Routes.order(widget.id);

    // Already paid or being checked: show where things stand, not the form.
    if (status != PaymentStatus.awaitingTransfer && status != PaymentStatus.rejected) {
      return Scaffold(
        appBar: AppBar(title: Text(t.bankakTitle)),
        body: EmptyState(
          icon: status == PaymentStatus.receiptSubmitted
              ? Icons.hourglass_top
              : Icons.check_circle_outline,
          title: status == null ? t.ordersEmpty : core.paymentStatus(status),
          message: status == PaymentStatus.receiptSubmitted ? t.bankakCheckingBody : null,
          action: status == null
              ? null
              : FilledButton(
                  onPressed: () => context.pushReplacement(details),
                  child: Text(t.orderTitle),
                ),
        ),
      );
    }

    Widget step(int n, String title, Widget child) => SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.secondary,
                child: Text(
                  '$n',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: Space.md),
          child,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.bankakTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          Card(
            color: AppColors.of(context).brandSurface,
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                children: [
                  Text(
                    t.bankakAmount,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.of(context).onBrandSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    context.sdg(amount),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AppColors.of(context).onBrandSurface,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Countdown(
                    until: payBy,
                    builder: (context, left) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, size: 18, color: AppPalette.amber400),
                        const SizedBox(width: Space.xs),
                        Text(
                          left == Duration.zero
                              ? core.payExpired
                              : t.bankakTimeLeft(clockText(left)),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppPalette.amber400,
                            fontFeatures: AppTypography.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          step(
            1,
            t.bankakStep1,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyValueRow(
                  label: t.bankakAccountName,
                  value: settings.bankakAccountName.tr(context),
                ),
                const SizedBox(height: Space.sm),
                CopyValue(label: t.bankakAccountNumber, value: settings.bankakAccountNumber),
                const SizedBox(height: Space.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusPill(label: t.bankakSample, tone: Tone.danger, icon: Icons.block),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          step(
            2,
            t.bankakStep2,
            CopyValue(label: t.bankakRef, value: ref_, display: formatRef(ref_), large: true),
          ),
          const SizedBox(height: Space.md),
          step(
            3,
            t.bankakStep3,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReceiptPicker(
                  attached: _receipt,
                  onTap: () => setState(() {
                    _receipt = !_receipt;
                    _showError = false;
                  }),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _txn,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textDirection: TextDirection.ltr,
                  onChanged: (_) => setState(() => _showError = false),
                  decoration: InputDecoration(
                    labelText: '${t.bankakTxn} (${core.optional})',
                    helperText: t.bankakTxnHint,
                    errorText: _showError ? t.bankakNeedProof : null,
                    prefixIcon: const Icon(Icons.pin_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          InfoBanner(tone: Tone.neutral, icon: Icons.shield_outlined, message: t.bankakNever),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(t.bankakSubmit),
        ),
      ),
    );
  }
}

class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({required this.attached, required this.onTap});

  final bool attached;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    return Material(
      color: attached ? colors.successContainer : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(color: attached ? colors.success : scheme.outline),
      ),
      child: InkWell(
        borderRadius: Radii.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              Icon(
                attached ? Icons.check_circle_rounded : Icons.upload_file_outlined,
                size: 32,
                color: attached ? colors.success : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  attached ? t.bankakUploaded : t.bankakUpload,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: attached ? colors.onSuccessContainer : scheme.onSurface,
                  ),
                ),
              ),
              if (attached) Icon(Icons.close, color: colors.onSuccessContainer),
            ],
          ),
        ),
      ),
    );
  }
}
