import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/shop.dart';
import '../../widgets/partner_widgets.dart';

/// Buyers' photo requests the shop can quote on (`shop_open_requests`, `shop_make_offer`).
class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.quickQuotes)),
      body: AsyncBody(
        value: ref.watch(quotesProvider),
        onRefresh: () => ref.read(quotesProvider.notifier).refresh(),
        data: (quotes) => ListView(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
          children: [
            InfoBanner(tone: Tone.info, icon: Icons.photo_camera_outlined, message: t.quotesBody),
            const SizedBox(height: Space.lg),
            if (quotes.isEmpty)
              EmptyState(icon: Icons.request_quote_outlined, title: t.quotesEmpty),
            for (final q in quotes) ...[
              _QuoteCard(key: ValueKey(q.request.id), quote: q),
              const SizedBox(height: Space.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends ConsumerWidget {
  const _QuoteCard({super.key, required this.quote});

  final OpenRequest quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final now = ref.watch(clockProvider)();
    final r = quote.request;
    final mine = quote.myOffer;
    final others = quote.offerCount - (mine == null ? 0 : 1);
    final hoursLeft = r.expiresAt.difference(now).inHours;
    final urls = ref.watch(requestPhotoUrlsProvider(r.imageKeys.join('\n'))).value ?? const {};
    final first = r.imageKeys.firstOrNull;

    void offer() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OfferSheet(quote: quote),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: Radii.smAll,
                  onTap: r.imageKeys.isEmpty
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => _Photos(urls: [for (final k in r.imageKeys) ?urls[k]]),
                        ),
                  child: Container(
                    width: 72,
                    height: 72,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: Radii.smAll,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (first != null && urls[first] != null)
                          Image.network(
                            urls[first]!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                          )
                        else
                          Icon(Icons.image_outlined, color: theme.colorScheme.onSurfaceVariant),
                        if (r.imageKeys.length > 1)
                          PositionedDirectional(
                            bottom: 4,
                            end: 4,
                            child: StatusPill(
                              label: '${r.imageKeys.length}',
                              icon: Icons.photo_library_outlined,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.note, style: theme.textTheme.titleSmall),
                      if (r.variantId != null && catalogue.hasVariant(r.variantId!))
                        Text(
                          carLabel(context, catalogue, r.variantId!),
                          style: theme.textTheme.bodySmall,
                        ),
                      if (r.categoryId != null)
                        Text(
                          catalogue.category(r.categoryId!).name.tr(context),
                          style: theme.textTheme.bodySmall,
                        ),
                      Text(r.buyerName, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                StatusPill(
                  label: t.expiresIn(hoursLeft.clamp(1, 72)),
                  icon: Icons.timer_outlined,
                  tone: hoursLeft < 6 ? Tone.warning : Tone.neutral,
                ),
                StatusPill(label: t.otherOffers(others), icon: Icons.storefront_outlined),
              ],
            ),
            const SizedBox(height: Space.md),
            if (mine != null) ...[
              InfoBanner(
                tone: Tone.success,
                message: t.yourOffer(context.sdg(mine.priceSdg)),
                action: TextButton(onPressed: offer, child: Text(t.changeOffer)),
              ),
            ] else
              FilledButton.icon(
                onPressed: offer,
                icon: const Icon(Icons.send_outlined),
                label: Text(t.makeOffer),
              ),
          ],
        ),
      ),
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(Space.lg),
    clipBehavior: Clip.antiAlias,
    child: AspectRatio(
      aspectRatio: 3 / 4,
      child: PageView(
        children: [
          for (final u in urls) InteractiveViewer(child: Image.network(u, fit: BoxFit.contain)),
        ],
      ),
    ),
  );
}

class _OfferSheet extends ConsumerStatefulWidget {
  const _OfferSheet({required this.quote});

  final OpenRequest quote;

  @override
  ConsumerState<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends ConsumerState<_OfferSheet> {
  late final _desc = TextEditingController(
    text: widget.quote.myOffer?.title.ar ?? widget.quote.request.note,
  );
  late final _price = TextEditingController(text: '${widget.quote.myOffer?.priceSdg ?? ''}');
  final _note = TextEditingController();
  late var _condition = widget.quote.myOffer?.condition ?? ListingCondition.newAftermarket;
  late var _warranty = widget.quote.myOffer?.warrantyDays ?? 30;
  var _busy = false;

  @override
  void dispose() {
    _desc.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = context.t;
    setState(() => _busy = true);
    try {
      await ref
          .read(quotesProvider.notifier)
          .offer(
            widget.quote.request.id,
            OfferDraft(
              title: _desc.text.trim(),
              condition: _condition,
              priceSdg: int.parse(_price.text),
              warrantyDays: _warranty,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            ),
          );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, t.offerSent);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final price = int.tryParse(_price.text) ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.offerTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: Space.lg),
              TextField(
                controller: _desc,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: t.offerPart),
              ),
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.sm,
                children: [
                  for (final c in ListingCondition.values)
                    ChoiceChip(
                      label: Text(core.condition(c)),
                      selected: _condition == c,
                      onSelected: (_) => setState(() => _condition = c),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textDirection: TextDirection.ltr,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: t.priceField),
              ),
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final d in [0, 30, 90, 180])
                    ChoiceChip(
                      label: Text(core.warranty(d)),
                      selected: _warranty == d,
                      onSelected: (_) => setState(() => _warranty = d),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              TextField(
                controller: _note,
                maxLines: 2,
                maxLength: 300,
                decoration: InputDecoration(labelText: t.offerNote),
              ),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: price <= 0 || _desc.text.trim().isEmpty || _busy ? null : _send,
                child: Text(t.makeOffer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
