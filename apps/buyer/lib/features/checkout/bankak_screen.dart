import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/bookings.dart';
import '../../state/orders.dart';
import '../../widgets/buyer_widgets.dart';

/// Bankak confirmed transfer: amount, account, order number to type in the note, then
/// the receipt and/or transaction number. An admin confirms it against the bank
/// statement; the screenshot alone never marks it paid (brief §1).
///
/// A fitting is always paid through its order (D-097), so [isBooking] only finds the
/// booking's order.
class BankakScreen extends ConsumerWidget {
  const BankakScreen({super.key, required this.id, this.isBooking = false});

  final String id;
  final bool isBooking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isBooking) return _OrderPayment(orderId: id);
    final booking = ref.watch(bookingProvider(id));
    return switch (booking) {
      AsyncData(value: Booking(:final orderId?)) => _OrderPayment(orderId: orderId),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: Text(context.t.bankakTitle)),
        body: EmptyState(icon: Icons.cloud_off_outlined, title: context.core.error(error)),
      ),
      _ => Scaffold(
        appBar: AppBar(title: Text(context.t.bankakTitle)),
        body: const SkeletonList(),
      ),
    };
  }
}

class _OrderPayment extends ConsumerStatefulWidget {
  const _OrderPayment({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_OrderPayment> createState() => _OrderPaymentState();
}

class _OrderPaymentState extends ConsumerState<_OrderPayment> {
  final _txn = TextEditingController();
  PickedPhoto? _receipt;
  var _sending = false;
  var _showError = false;
  final _idem = newIdempotencyKey();

  @override
  void dispose() {
    _txn.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.core.photoGallery),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.core.photoCamera),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;
    final photo = await Photos.pick(camera: camera);
    if (photo != null && mounted) {
      setState(() {
        _receipt = photo;
        _showError = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_receipt == null && _txn.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(orderProvider(widget.orderId).notifier)
          .submitReceipt(
            txnNo: _txn.text.trim(),
            receipt: _receipt?.bytes,
            fileName: _receipt?.fileName,
            idem: _idem,
          );
      if (mounted) context.pushReplacement(Routes.order(widget.orderId));
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final order = ref.watch(orderProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text(t.bankakTitle)),
      body: switch (order) {
        AsyncData(value: final o?) => _body(context, o),
        AsyncData() => EmptyState(
          icon: Icons.receipt_long_outlined,
          title: context.core.errNotFound,
        ),
        AsyncError(:final error) => EmptyState(
          icon: Icons.cloud_off_outlined,
          title: context.core.error(error),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(orderProvider(widget.orderId)),
            child: Text(context.core.actionRetry),
          ),
        ),
        _ => const SkeletonList(),
      },
      bottomNavigationBar: switch (order.value) {
        final o? when o.needsTransfer => BottomActionBar(
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
        _ => null,
      },
    );
  }

  Widget _body(BuildContext context, Order order) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final settings = ref.watch(platformSettingsProvider);
    final status = order.bankakStatus;
    final account = settings.bankakAccountNumber;
    final sample =
        account.isEmpty || account.startsWith('TODO') || RegExp(r'^0+$').hasMatch(account);

    // Already paid, being checked or closed: show where things stand, not the form.
    if (!order.needsTransfer) {
      return EmptyState(
        icon: status == PaymentStatus.receiptSubmitted
            ? Icons.hourglass_top
            : Icons.check_circle_outline,
        title: core.paymentStatus(status),
        message: status == PaymentStatus.receiptSubmitted ? t.bankakCheckingBody : null,
        action: FilledButton(
          onPressed: () => context.pushReplacement(Routes.order(order.id)),
          child: Text(t.orderTitle),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
      children: [
        if (status == PaymentStatus.rejected) ...[
          InfoBanner(
            tone: Tone.danger,
            title: t.bankakRejected,
            message: t.bankakRejectedBody(rejectReason(context, order.rejectReason)),
          ),
          const SizedBox(height: Space.md),
        ],
        Card(
          color: AppColors.of(context).brandSurface,
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              children: [
                Text(
                  order.method == PaymentMethod.cash ? t.bankakDepositAmount : t.bankakAmount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.of(context).onBrandSurfaceMuted,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  context.sdg(order.bankakDueSdg),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.of(context).onBrandSurface,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Countdown(
                  until: order.payBy,
                  builder: (context, left) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 18, color: AppPalette.amber400),
                      const SizedBox(width: Space.xs),
                      Text(
                        left == Duration.zero ? core.payExpired : t.bankakTimeLeft(clockText(left)),
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
              CopyValue(label: t.bankakAccountNumber, value: account),
              if (sample) ...[
                const SizedBox(height: Space.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusPill(label: t.bankakSample, tone: Tone.danger, icon: Icons.block),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        step(
          2,
          t.bankakStep2,
          CopyValue(
            label: t.bankakRef,
            value: order.ref,
            display: formatRef(order.ref),
            large: true,
          ),
        ),
        const SizedBox(height: Space.md),
        step(
          3,
          t.bankakStep3,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReceiptPicker(
                attached: _receipt != null,
                onTap: _receipt == null ? _pick : () => setState(() => _receipt = null),
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
    );
  }
}

/// Why an admin didn't accept a receipt, in the buyer's words.
String rejectReason(BuildContext context, String? code) {
  final t = context.t;
  return switch (code) {
    'AMOUNT_WRONG' => t.rejectAmount,
    'NOT_ON_STATEMENT' => t.rejectNotFound,
    'DUPLICATE' => t.rejectDuplicate,
    'UNREADABLE' => t.rejectUnreadable,
    _ => t.rejectOther,
  };
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
