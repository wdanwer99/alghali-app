import 'package:alghali_core/alghali_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';

/// Schematic of Alghali Street: the road, its zones, and every shop as a dot
/// on side A (above) or side B (below), placed by metres from the north end.
/// The north end sits at the reading start, so the strip mirrors in Arabic.
class StreetStrip extends StatelessWidget {
  const StreetStrip({
    super.key,
    required this.catalogue,
    this.compact = false,
    this.selectedShopId,
    this.highlight,
    this.onShopTap,
  });

  final CatalogueData catalogue;

  /// Small, non-interactive version that fits its width (home preview).
  final bool compact;
  final String? selectedShopId;

  /// Shops to emphasise (e.g. the ones selling a category); null = all.
  final Set<String>? highlight;
  final ValueChanged<Shop>? onShopTap;

  static const _pxPerMetre = 1.1;
  static const _pad = 64.0;

  // Rows, top to bottom: side-A names · side-A dots · road · side-B dots ·
  // side-B names · zone names.
  static const _height = 206.0;
  static const _roadTop = 74.0;
  static const _roadHeight = 30.0;
  static const _markerTopA = 24.0;
  static const _markerTopB = 110.0;
  static const _labelWidth = 128.0;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // At least 100 m, so an empty street (first launch offline) still draws.
    final length = catalogue.zones.fold(100, (m, z) => z.toM > m ? z.toM : m).toDouble();

    if (compact) {
      return LayoutBuilder(
        builder: (context, box) => CustomPaint(
          size: box.biggest,
          painter: _StreetPainter(
            zones: const [],
            shops: catalogue.shops,
            scale: (box.maxWidth - 16) / length,
            inset: 8,
            rtl: rtl,
            compact: true,
            colors: _StreetColors.of(context),
          ),
        ),
      );
    }

    return _ScrollingStrip(strip: this, rtl: rtl, length: length);
  }
}

class _ScrollingStrip extends StatefulWidget {
  const _ScrollingStrip({required this.strip, required this.rtl, required this.length});

  final StreetStrip strip;
  final bool rtl;
  final double length;

  @override
  State<_ScrollingStrip> createState() => _ScrollingStripState();
}

class _ScrollingStripState extends State<_ScrollingStrip> {
  final _controller = ScrollController();

  double get _width => widget.length * StreetStrip._pxPerMetre + StreetStrip._pad * 2;

  @override
  void initState() {
    super.initState();
    _scrollToSelected();
  }

  @override
  void didUpdateWidget(_ScrollingStrip old) {
    super.didUpdateWidget(old);
    if (old.strip.selectedShopId != widget.strip.selectedShopId) _scrollToSelected();
  }

  /// Centres the selected shop once the viewport size is known.
  void _scrollToSelected() {
    final shop = widget.strip.catalogue.shops
        .where((s) => s.id == widget.strip.selectedShopId)
        .firstOrNull;
    if (shop == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final viewport = _controller.position.viewportDimension;
      final target = StreetStrip._pad + shop.posM * StreetStrip._pxPerMetre - viewport / 2;
      _controller.animateTo(
        target.clamp(0, _controller.position.maxScrollExtent),
        duration: Motion.slow,
        curve: Motion.curve,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strip = widget.strip;
    final colors = _StreetColors.of(context);
    const height = StreetStrip._height;
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _StreetPainter(
                  zones: [
                    for (final z in strip.catalogue.zones)
                      (z.fromM.toDouble(), z.toM.toDouble(), z.name.tr(context)),
                  ],
                  ends: (context.t.streetNorth, context.t.streetSouth),
                  shops: const [],
                  scale: StreetStrip._pxPerMetre,
                  inset: StreetStrip._pad,
                  rtl: widget.rtl,
                  colors: colors,
                  textStyle: Theme.of(context).textTheme.labelSmall!,
                ),
              ),
            ),
            for (final shop in strip.catalogue.shops) ...[
              PositionedDirectional(
                start:
                    StreetStrip._pad +
                    shop.posM * StreetStrip._pxPerMetre -
                    StreetStrip._labelWidth / 2,
                top: shop.side == StreetSide.a ? 2 : StreetStrip._markerTopB + 46,
                width: StreetStrip._labelWidth,
                child: ExcludeSemantics(
                  child: Text(
                    shop.name.tr(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: shop.id == strip.selectedShopId
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: strip.highlight != null && !strip.highlight!.contains(shop.id)
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: StreetStrip._pad + shop.posM * StreetStrip._pxPerMetre - 22,
                top: shop.side == StreetSide.a ? StreetStrip._markerTopA : StreetStrip._markerTopB,
                child: _ShopMarker(
                  shop: shop,
                  selected: shop.id == strip.selectedShopId,
                  dimmed: strip.highlight != null && !strip.highlight!.contains(shop.id),
                  colors: colors,
                  onTap: strip.onShopTap == null ? null : () => strip.onShopTap!(shop),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShopMarker extends StatelessWidget {
  const _ShopMarker({
    required this.shop,
    required this.selected,
    required this.dimmed,
    required this.colors,
    this.onTap,
  });

  final Shop shop;
  final bool selected;
  final bool dimmed;
  final _StreetColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = selected ? 34.0 : 28.0;
    return Semantics(
      button: true,
      selected: selected,
      label: '${shop.name.tr(context)}, ${context.core.plot(shop.plotNo)}',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.fast,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? scheme.primary
                    : dimmed
                    ? scheme.surfaceContainerHigh
                    : scheme.surface,
                border: Border.all(
                  color: selected ? scheme.primary : (dimmed ? colors.tick : scheme.secondary),
                  width: 2,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.3), blurRadius: 8)]
                    : null,
              ),
              child: Text(
                shop.plotNo,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: shop.plotNo.length > 2 ? 9.5 : 11,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? scheme.onPrimary
                      : dimmed
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreetColors {
  const _StreetColors({
    required this.road,
    required this.lane,
    required this.tick,
    required this.zoneA,
    required this.zoneB,
    required this.dot,
  });

  factory _StreetColors.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return _StreetColors(
      road: dark ? AppPalette.gray600 : AppPalette.gray700,
      lane: AppPalette.amber400,
      tick: scheme.outline,
      zoneA: scheme.surfaceContainer,
      zoneB: scheme.surfaceContainerHigh,
      dot: scheme.secondary,
    );
  }

  final Color road;
  final Color lane;
  final Color tick;
  final Color zoneA;
  final Color zoneB;
  final Color dot;
}

class _StreetPainter extends CustomPainter {
  _StreetPainter({
    required this.zones,
    required this.shops,
    required this.scale,
    required this.inset,
    required this.rtl,
    required this.colors,
    this.ends,
    this.compact = false,
    this.textStyle,
  });

  final List<(double, double, String)> zones;
  final List<Shop> shops;
  final double scale;
  final double inset;
  final bool rtl;
  final bool compact;
  final _StreetColors colors;
  final (String, String)? ends;
  final TextStyle? textStyle;

  double _x(double metres, double width) {
    final x = inset + metres * scale;
    return rtl ? width - x : x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final roadH = compact ? 14.0 : StreetStrip._roadHeight;
    final roadTop = compact ? (size.height - roadH) / 2 : StreetStrip._roadTop;
    final road = Rect.fromLTWH(0, roadTop, size.width, roadH);
    final zoneLabelTop = size.height - 20;

    // Zone bands behind the road, alternating tints; the ends take the first tint.
    if (zones.isNotEmpty) {
      canvas.drawRect(
        Rect.fromLTRB(0, 0, size.width, zoneLabelTop - 2),
        Paint()..color = colors.zoneA,
      );
    }
    for (final (i, (from, to, label)) in zones.indexed) {
      final a = _x(from, size.width);
      final b = _x(to, size.width);
      final band = Rect.fromLTRB(a < b ? a : b, 0, a < b ? b : a, zoneLabelTop - 2);
      canvas.drawRect(band, Paint()..color = i.isEven ? colors.zoneA : colors.zoneB);
      if (textStyle != null) {
        final tp = TextPainter(
          text: TextSpan(text: label, style: textStyle),
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: band.width - 8);
        tp.paint(canvas, Offset(band.center.dx - tp.width / 2, zoneLabelTop + 1));
      }
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(road, Radius.circular(roadH / 2)),
      Paint()..color = colors.road,
    );
    // Dashed centre line, kept clear of the "North"/"South" labels at the ends.
    final lane = Paint()
      ..color = colors.lane
      ..strokeWidth = compact ? 1.5 : 2;
    final clear = compact ? 8.0 : inset;
    for (var x = clear; x < size.width - clear; x += compact ? 10 : 18) {
      canvas.drawLine(
        Offset(x, road.center.dy),
        Offset(x + (compact ? 5 : 9), road.center.dy),
        lane,
      );
    }

    if (ends != null && textStyle != null) {
      final (north, south) = ends!;
      for (final (label, atStart) in [(north, true), (south, false)]) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: textStyle!.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        )..layout();
        final leftSide = atStart != rtl;
        tp.paint(
          canvas,
          Offset(leftSide ? 10 : size.width - tp.width - 10, road.center.dy - tp.height / 2),
        );
      }
    }

    if (compact) {
      for (final s in shops) {
        final x = _x(s.posM.toDouble(), size.width);
        final y = s.side == StreetSide.a ? road.top - 10 : road.bottom + 10;
        canvas.drawCircle(Offset(x, y), 6, Paint()..color = colors.dot);
        canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_StreetPainter old) =>
      old.rtl != rtl ||
      old.scale != scale ||
      old.zones.length != zones.length ||
      old.colors.road != colors.road;
}
