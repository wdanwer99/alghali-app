import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/shop_state.dart';
import '../../widgets/partner_widgets.dart';

/// Buyers' photo requests the shop can quote on (`shop_make_offer`).
class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final quotes = ref.watch(quotesProvider);
    final catalogue = ref.watch(catalogueProvider);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(title: Text(t.quickQuotes)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          InfoBanner(tone: Tone.info, icon: Icons.photo_camera_outlined, message: t.quotesBody),
          const SizedBox(height: Space.lg),
          if (quotes.isEmpty) EmptyState(icon: Icons.request_quote_outlined, title: t.quotesEmpty),
          for (final q in quotes) ...[
            Card(
              key: ValueKey(q.request.id),
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: Radii.smAll,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.image_outlined, color: theme.colorScheme.onSurfaceVariant),
                              if (q.request.photoCount > 1)
                                PositionedDirectional(
                                  bottom: 4,
                                  end: 4,
                                  child: StatusPill(
                                    label: '${q.request.photoCount}',
                                    icon: Icons.photo_library_outlined,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q.request.note, style: theme.textTheme.titleSmall),
                              if (q.request.variantId != null)
                                Text(
                                  carLabel(context, catalogue, q.request.variantId!),
                                  style: theme.textTheme.bodySmall,
                                ),
                              Text(q.buyerName, style: theme.textTheme.bodySmall),
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
                          label: t.expiresIn(
                            q.request.expiresAt.difference(now).inHours.clamp(1, 24),
                          ),
                          icon: Icons.timer_outlined,
                          tone: q.request.expiresAt.difference(now).inHours < 6
                              ? Tone.warning
                              : Tone.neutral,
                        ),
                        StatusPill(
                          label: t.otherOffers(q.otherOffers),
                          icon: Icons.storefront_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    if (q.myOfferSdg != null)
                      InfoBanner(
                        tone: Tone.success,
                        message: t.yourOffer(context.sdg(q.myOfferSdg!)),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _OfferSheet(quote: q),
                        ),
                        icon: const Icon(Icons.send_outlined),
                        label: Text(t.makeOffer),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
          ],
          const SizedBox(height: Space.md),
          DemoControls(
            label: t.demoNewQuote,
            onTap: () => ref.read(quotesProvider.notifier).demoNew(),
          ),
        ],
      ),
    );
  }
}

class _OfferSheet extends ConsumerStatefulWidget {
  const _OfferSheet({required this.quote});

  final QuoteRequest quote;

  @override
  ConsumerState<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends ConsumerState<_OfferSheet> {
  late final _desc = TextEditingController(text: widget.quote.request.note);
  final _price = TextEditingController();
  var _condition = ListingCondition.newAftermarket;
  var _warranty = 30;

  @override
  void dispose() {
    _desc.dispose();
    _price.dispose();
    super.dispose();
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
              TextField(maxLines: 2, decoration: InputDecoration(labelText: t.offerNote)),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: price <= 0
                    ? null
                    : () {
                        ref.read(quotesProvider.notifier).sendOffer(widget.quote.request.id, price);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(t.offerSent)));
                      },
                child: Text(t.makeOffer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
