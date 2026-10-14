import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/cart.dart';
import '../../state/garage.dart';
import '../../state/requests.dart';
import '../../state/session.dart';
import '../../widgets/buyer_widgets.dart';

/// Asks camera or gallery, then picks one photo (already shrunk for upload).
Future<PickedPhoto?> pickPhoto(BuildContext context) async {
  final camera = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(context.core.photoCamera),
            onTap: () => Navigator.pop(context, true),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(context.core.photoGallery),
            onTap: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
  if (camera == null) return null;
  return Photos.pick(camera: camera);
}

/// "Can't find it? Send a photo": shops that sell the category get notified and answer
/// with offers (PLAN §3.5 part_requests / part_offers). Needs a connection to upload.
class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  static const _maxPhotos = 3;
  final _note = TextEditingController();
  final _photos = <PickedPhoto>[];
  String? _categoryId;
  var _showPhotoError = false;
  var _sending = false;
  final _idem = newIdempotencyKey();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final p = await pickPhoto(context);
    if (p != null && mounted) {
      setState(() {
        _photos.add(p);
        _showPhotoError = false;
      });
    }
  }

  Future<void> _send() async {
    if (_photos.isEmpty) {
      setState(() => _showPhotoError = true);
      return;
    }
    if (_note.text.trim().isEmpty) return;
    if (!ref.read(sessionProvider).signedIn) {
      await context.push<void>(Routes.signIn);
      if (!mounted || !ref.read(sessionProvider).signedIn) return;
    }
    setState(() => _sending = true);
    try {
      final request = await ref
          .read(requestsProvider.notifier)
          .create(
            note: _note.text.trim(),
            photos: _photos,
            variantId: ref.read(selectedVariantProvider),
            categoryId: _categoryId,
            idem: _idem,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.requestSent)));
      context.pushReplacement(Routes.request(request.id));
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
          Text(t.requestPhotos(_photos.length), style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              for (var i = 0; i < _maxPhotos; i++) ...[
                if (i > 0) const SizedBox(width: Space.sm),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: i < _photos.length
                        ? Stack(
                            children: [
                              Positioned.fill(
                                child: Semantics(
                                  label: t.photoPlaceholder(i + 1),
                                  image: true,
                                  child: ClipRRect(
                                    borderRadius: Radii.mdAll,
                                    child: Image.memory(
                                      _photos[i].bytes,
                                      fit: BoxFit.cover,
                                      cacheWidth: 360,
                                    ),
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                top: 0,
                                end: 0,
                                child: IconButton(
                                  tooltip: core.actionRemove,
                                  onPressed: () => setState(() => _photos.removeAt(i)),
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
                                color: _showPhotoError && _photos.isEmpty
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.outline,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: Radii.mdAll,
                              onTap: i == _photos.length ? _add : null,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  if (i == _photos.length)
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
          if (_showPhotoError && _photos.isEmpty)
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
            maxLength: 500,
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
          icon: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
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
    final list = ref.watch(requestsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.requestTitle)),
      body: AsyncBody(
        value: list,
        onRefresh: () => ref.read(requestsProvider.notifier).refresh(),
        data: (requests) => switch (requests.where((r) => r.id == requestId).firstOrNull) {
          final r? => _RequestBody(request: r),
          null => ListView(
            children: [EmptyState(icon: Icons.photo_camera_outlined, title: t.requestsEmpty)],
          ),
        },
      ),
    );
  }
}

class _RequestBody extends ConsumerWidget {
  const _RequestBody({required this.request});

  final PartRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final r = request;
    final catalogue = ref.watch(catalogueProvider);
    final now = ref.watch(clockProvider)();
    final cartOfferIds = {for (final l in ref.watch(cartProvider).lines) ?l.offerId};
    final hoursLeft = r.expiresAt.difference(now).inHours.clamp(1, 72);
    final photos = ref.watch(requestPhotoUrlsProvider(r.imageKeys.join('\n'))).value ?? const {};
    final offers = [...r.offers]
      ..sort((a, b) => (a.live == b.live) ? a.priceSdg.compareTo(b.priceSdg) : (a.live ? -1 : 1));

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final key in r.imageKeys) ...[
                    ClipRRect(
                      borderRadius: Radii.smAll,
                      child: SizedBox.square(
                        dimension: 64,
                        child: photos[key] == null
                            ? ColoredBox(
                                color: theme.colorScheme.surfaceContainerHigh,
                                child: Icon(
                                  Icons.image_outlined,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Image.network(
                                photos[key]!,
                                fit: BoxFit.cover,
                                cacheWidth: 192,
                                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                              ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                  ],
                ],
              ),
              const SizedBox(height: Space.md),
              Text(r.note, style: theme.textTheme.titleMedium),
              if (r.variantId != null)
                Text(carLabel(context, catalogue, r.variantId!), style: theme.textTheme.bodySmall),
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
          title: t.requestOffers(offers.where((o) => o.live).length),
          padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
        ),
        if (offers.isEmpty)
          EmptyState(
            icon: Icons.hourglass_empty,
            title: t.requestOffers(0),
            message: t.requestNoOffersBody,
            compact: true,
          )
        else
          for (final o in offers) ...[
            _OfferCard(offer: o, request: r, inCart: cartOfferIds.contains(o.id)),
            const SizedBox(height: Space.sm),
          ],
        if (r.status == RequestStatus.open) ...[
          const SizedBox(height: Space.md),
          OutlinedButton(
            onPressed: () async {
              try {
                await ref.read(requestsProvider.notifier).close(r.id);
              } on BackendException catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
            child: Text(t.requestClose),
          ),
        ],
        const SizedBox(height: Space.sm),
        Text(core.pullToRefresh, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.offer, required this.request, required this.inCart});

  final PartOffer offer;
  final PartRequest request;
  final bool inCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final o = offer;
    final shop = catalogue.shop(o.shopId);
    return Opacity(
      opacity: o.live ? 1 : 0.55,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InitialsAvatar(name: shop.name.tr(context), size: 40),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shop.name.tr(context), style: theme.textTheme.titleSmall),
                        RatingLine(rating: shop.rating, dense: true),
                      ],
                    ),
                  ),
                  PriceText(text: context.sdg(o.priceSdg)),
                ],
              ),
              const SizedBox(height: Space.md),
              Text(o.title.tr(context), style: theme.textTheme.bodyLarge),
              if (o.note != null) Text(o.note!.tr(context), style: theme.textTheme.bodySmall),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                children: [
                  StatusPill(label: core.condition(o.condition)),
                  StatusPill(label: core.warranty(o.warrantyDays)),
                  StatusPill(
                    label: o.live
                        ? t.requestValidUntil(context.dayTime(o.validUntil))
                        : t.requestOfferClosed,
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
                      onPressed: inCart || !o.live
                          ? null
                          : () {
                              ref
                                  .read(cartProvider.notifier)
                                  .addOffer(o, categoryId: request.categoryId ?? '');
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
                      icon: Icon(inCart ? Icons.check : Icons.add_shopping_cart, size: 20),
                      label: Text(t.partAddToCart),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
