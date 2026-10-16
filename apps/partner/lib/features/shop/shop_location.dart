import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/tech.dart';

typedef MapPoint = ({double lat, double lng});

/// Whether the picker loads map tiles. Widget tests turn it off: they have no network.
final mapTilesEnabledProvider = Provider<bool>((_) => true);

/// Where the map opens when the shop has no pin and the street has no starting point.
const _khartoum = LatLng(15.5007, 32.5599);

/// The shop's pin for buyers' "Directions" button (D-145): optional when applying and in
/// the profile. Shows what is set and opens [LocationPickerScreen] to set or change it.
class ShopLocationField extends StatelessWidget {
  const ShopLocationField({super.key, required this.value, required this.onChanged});

  final MapPoint? value;
  final ValueChanged<MapPoint?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await context.push<MapPoint>(Routes.pickLocation, extra: value);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final point = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.shopLocationBody, style: theme.textTheme.bodySmall),
        const SizedBox(height: Space.sm),
        if (point == null)
          OutlinedButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(t.shopLocationPick),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.of(context).success),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text(t.shopLocationIsSet, style: theme.textTheme.titleSmall)),
                      Text(
                        '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: Space.xs,
                    children: [
                      TextButton.icon(
                        onPressed: () => _pick(context),
                        icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                        label: Text(t.shopLocationChange),
                      ),
                      TextButton.icon(
                        onPressed: () => Launch.mapAt(point.lat, point.lng),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(t.shopLocationView),
                      ),
                      TextButton.icon(
                        onPressed: () => onChanged(null),
                        icon: const Icon(Icons.location_off_outlined, size: 18),
                        label: Text(t.shopLocationRemove),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A full-screen map with a pin fixed in the middle: the owner moves the map under it, or
/// jumps to where the phone is, then confirms. Pops with the chosen point. OpenStreetMap
/// tiles, so no Google key (D-145).
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final MapPoint? initial;

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _map = MapController();
  late LatLng _center = _start();
  var _locating = false;

  LatLng _start() {
    if (widget.initial case final p?) return LatLng(p.lat, p.lng);
    if (ref.read(catalogueProvider).streetOrigin case final o?) return LatLng(o.lat, o.lng);
    return _khartoum;
  }

  Future<void> _here() async {
    setState(() => _locating = true);
    try {
      final (:lat, :lng) = await ref.read(gpsProvider)();
      if (!mounted) return;
      setState(() => _center = LatLng(lat, lng));
      _map.move(_center, 18);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.pickLocationTitle)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial == null ? 16 : 18,
              minZoom: 5,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, _) => _center = camera.center,
            ),
            children: [
              if (ref.watch(mapTilesEnabledProvider))
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'sd.alghali.partner',
                ),
              const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
            ],
          ),
          // The pin's tip sits on the map's centre.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on, size: 48, color: theme.colorScheme.primary),
              ),
            ),
          ),
          PositionedDirectional(
            top: Space.md,
            start: Space.md,
            end: Space.md,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Text(t.pickLocationHint, style: theme.textTheme.bodyMedium),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: Space.xl,
            end: Space.lg,
            child: FloatingActionButton.extended(
              heroTag: null,
              onPressed: _locating ? null : _here,
              icon: _locating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(t.pickLocationHere),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: () => context.pop<MapPoint>((lat: _center.latitude, lng: _center.longitude)),
          child: Text(t.pickLocationConfirm),
        ),
      ),
    );
  }
}
