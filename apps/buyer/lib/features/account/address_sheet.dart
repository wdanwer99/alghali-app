import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/account.dart';

/// Adds a place for deliveries and fittings: the phone's GPS point, a short label and
/// written directions (brief §6: GPS only for the buyer's address). Returns the new
/// address, or null when dismissed.
Future<Address?> showAddressSheet(BuildContext context) => showModalBottomSheet<Address>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _AddressSheet(),
);

class _AddressSheet extends ConsumerStatefulWidget {
  const _AddressSheet();

  @override
  ConsumerState<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends ConsumerState<_AddressSheet> {
  final _label = TextEditingController();
  final _directions = TextEditingController();
  ({double lat, double lng})? _point;
  var _locating = false;
  var _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _directions.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final p = await Gps.here();
      if (mounted) setState(() => _point = p);
    } on Object catch (e) {
      if (mounted) {
        showError(context, e is BackendException ? e : const BackendException('LOCATION_OFF'));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final p = _point;
    if (p == null || _label.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final a = await ref
          .read(addressesProvider.notifier)
          .add(label: _label.text, description: _directions.text, lat: p.lat, lng: p.lng);
      if (mounted) Navigator.pop(context, a);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final p = _point;
    final km = p == null ? null : kmFromStreet(catalogue, p.lat, p.lng);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.addressNew, style: theme.textTheme.titleLarge),
              const SizedBox(height: Space.sm),
              Text(t.addressNewBody, style: theme.textTheme.bodySmall),
              const SizedBox(height: Space.lg),
              if (p == null)
                OutlinedButton.icon(
                  onPressed: _locating ? null : _locate,
                  icon: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(t.bookUseLocation),
                )
              else
                InfoBanner(
                  tone: Tone.success,
                  icon: Icons.check_circle_outline,
                  message: km == null || km == 0
                      ? t.addressLocated
                      : '${t.addressLocated} · ${t.addressFromStreet(context.core.distance(km))}',
                  action: TextButton(onPressed: _locate, child: Text(t.addressLocateAgain)),
                ),
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.sm,
                children: [
                  for (final label in [t.addressHome, t.addressWork])
                    ActionChip(
                      label: Text(label),
                      onPressed: () => setState(() => _label.text = label),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              TextField(
                controller: _label,
                maxLength: 40,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: t.addressLabel),
              ),
              TextField(
                controller: _directions,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: t.addressDirections,
                  hintText: t.addressDirectionsHint,
                ),
              ),
              const SizedBox(height: Space.md),
              FilledButton(
                onPressed: _saving || p == null || _label.text.trim().isEmpty ? null : _save,
                child: Text(t.addressSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
