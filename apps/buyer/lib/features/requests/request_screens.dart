import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/cart.dart';
import '../../state/garage.dart';
import '../../state/orders.dart';
import '../../state/session.dart';
import '../../widgets/buyer_widgets.dart';
import '../orders/review_sheet.dart';

/// "Can't find it? Send a photo": shops that sell the category get notified
/// and answer with offers (PLAN §3.5 part_requests / part_offers).
class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  final _note = TextEditingController();
  var _photos = 0;
  String? _categoryId;
  var _showPhotoError = false;
  var _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_photos == 0) {
      setState(() => _showPhotoError = true);
      return;
    }
    if (_note.text.trim().isEmpty) return;
    if (!ref.read(sessionProvider).signedIn) {
      await context.push<void>(Routes.signIn);
      if (!mounted || !ref.read(sessionProvider).signedIn) return;
    }
    setState(() => _sending = true);
    final request = ref
        .read(requestsProvider.notifier)
        .create(
          note: _note.text.trim(),
          photoCount: _photos,
          variantId: ref.read(selectedVariantProvider),
          categoryId: _categoryId,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.requestSent)));
    context.pushReplacement(Routes.request(request.id));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final variantId = ref.watch(selectedVariantProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.requestNewTitle)),
      body: ListView(
        padding: Space.pageInsets,
        children: [
          InfoBanner(
            tone: Tone.info,
            icon: Icons.photo_camera_outlined,
            message: t.requestNewIntro,
          ),
          const SizedBox(height: Space.xl),
          Text(t.requestPhotos(_photos), style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: Space.sm),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: i < _photos
                        ? Stack(
                            children: [
                              Positioned.fill(
                                child: Semantics(
                                  label: t.photoPlaceholder(i + 1),
                                  image: true,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHigh,
                                      borderRadius: Radii.mdAll,
                                    ),
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 36,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                top: 0,
                                end: 0,
                                child: IconButton(
                                  tooltip: core.actionRemove,
                                  onPressed: () => setState(() => _photos--),
                                  icon: const Icon(Icons.cancel, size: 22),
                                ),
                              ),
                            ],
                          )
                        : Material(
                            color: theme.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: Radii.mdAll,
                              side: BorderSide(
                                color: _showPhotoError && _photos == 0
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.outline,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: Radii.mdAll,
                              onTap: i == _photos
                                  ? () => setState(() {
                                      _photos++;
                                      _showPhotoError = false;
                                    })
                                  : null,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  if (i == _photos)
                                    Text(
                                      t.requestAddPhoto,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelSmall,
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
          if (_showPhotoError && _photos == 0)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                t.requestNeedPhoto,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: Space.xl),
          TextField(
            controller: _note,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: t.requestNote, hintText: t.requestNoteHint),
          ),
          const SizedBox(height: Space.lg),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            decoration: InputDecoration(labelText: '${t.requestCategory} (${core.optional})'),
            items: [
              DropdownMenuItem(value: null, child: Text(t.streetAll)),
              for (final c in catalogue.categories)
                DropdownMenuItem(value: c.id, child: Text(c.name.tr(context))),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: Space.lg),
          if (variantId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconTile(icon: Icons.directions_car_filled),
              title: Text(t.requestCar),
              subtitle: Text(carLabel(context, catalogue, variantId)),
              trailing: TextButton(
                onPressed: () => context.push(Routes.garage),
                child: Text(t.homeChangeCar),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton.icon(
          onPressed: _sending || _note.text.trim().isEmpty ? null : _send,
          icon: const Icon(Icons.send_outlined),
          label: Text(t.requestSend),
        ),
      ),
    );
  }
}

class RequestScreen extends ConsumerWidget {
  const RequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final r = ref.watch(requestsProvider).where((r) => r.id == requestId).firstOrNull;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.photo_camera_outlined, title: t.requestsEmpty),
      );
    }
    final catalogue = ref.watch(catalogueProvider);
    final now = ref.watch(clockProvider)();
    final cartOfferIds = {for (final l in ref.watch(cartProvider)) ?l.offerId};
    final hoursLeft = r.expiresAt.difference(now).inHours.clamp(1, 24);

    return Scaffold(
      appBar: AppBar(title: Text(t.requestTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < r.photoCount; i++) ...[
                      Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsetsDirectional.only(end: Space.sm),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: Radii.smAll,
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Space.md),
                Text(r.note, style: theme.textTheme.titleMedium),
                if (r.variantId != null)
                  Text(
                    carLabel(context, catalogue, r.variantId!),
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  children: [
                    StatusPill(
                      label: switch (r.status) {
                        RequestStatus.open => t.requestStatusOpen,
                        RequestStatus.closed => t.requestStatusClosed,
                        RequestStatus.expired => t.requestStatusExpired,
                      },
                      tone: r.status == RequestStatus.open ? Tone.success : Tone.neutral,
                    ),
                    if (r.status == RequestStatus.open)
                      StatusPill(label: t.requestExpiresIn(hoursLeft), icon: Icons.timer_outlined),
                  ],
                ),
              ],
            ),
          ),
          SectionHeader(
            title: t.requestOffers(r.offers.length),
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
          ),
          if (r.offers.isEmpty)
            EmptyState(
              icon: Icons.hourglass_empty,
              title: t.requestOffers(0),
              message: t.requestNoOffersBody,
              compact: true,
            )
          else
            for (final o in r.offers) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          InitialsAvatar(name: catalogue.shop(o.shopId).name.tr(context), size: 40),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  catalogue.shop(o.shopId).name.tr(context),
                                  style: theme.textTheme.titleSmall,
                                ),
                                RatingLine(rating: catalogue.shop(o.shopId).rating, dense: true),
                              ],
                            ),
                          ),
                          PriceText(text: context.sdg(o.priceSdg)),
                        ],
                      ),
                      const SizedBox(height: Space.md),
                      Text(o.title.tr(context), style: theme.textTheme.bodyLarge),
                      if (o.note != null)
                        Text(o.note!.tr(context), style: theme.textTheme.bodySmall),
                      const SizedBox(height: Space.sm),
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.xs,
                        children: [
                          StatusPill(label: core.condition(o.condition)),
                          StatusPill(label: core.warranty(o.warrantyDays)),
                          StatusPill(
                            label: t.requestValidUntil(context.dayTime(o.validUntil)),
                            icon: Icons.schedule,
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, Hit.min)),
                              onPressed: () => context.push(Routes.chat(o.shopId)),
                              icon: const Icon(Icons.chat_bubble_outline, size: 20),
                              label: Text(core.actionChat),
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(minimumSize: const Size(0, Hit.min)),
                              onPressed: cartOfferIds.contains(o.id)
                                  ? null
                                  : () {
                                      ref
                                          .read(cartProvider.notifier)
                                          .addOffer(
                                            o,
                                            categoryId: r.categoryId ?? 'cat-accessories',
                                          );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(t.partAdded),
                                          action: SnackBarAction(
                                            label: t.partViewCart,
                                            onPressed: () => context.go(Routes.cart),
                                          ),
                                        ),
                                      );
                                    },
                              icon: Icon(
                                cartOfferIds.contains(o.id) ? Icons.check : Icons.add_shopping_cart,
                                size: 20,
                              ),
                              label: Text(t.partAddToCart),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.sm),
            ],
          if (r.status == RequestStatus.open) ...[
            const SizedBox(height: Space.md),
            OutlinedButton(
              onPressed: () => ref.read(requestsProvider.notifier).close(r.id),
              child: Text(t.requestClose),
            ),
            const SizedBox(height: Space.lg),
            DemoControls(onNext: () => ref.read(requestsProvider.notifier).demoAddOffer(r.id)),
          ],
        ],
      ),
    );
  }
}
