import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

@immutable
class GarageState {
  const GarageState({this.vehicles = const [], this.selectedId});

  final List<GarageVehicle> vehicles;
  final String? selectedId;

  GarageVehicle? get selected =>
      vehicles.where((v) => v.id == selectedId).firstOrNull ?? vehicles.firstOrNull;
}

/// My Garage, kept on the device so it works offline and before sign-in.
class GarageController extends Notifier<GarageState> {
  static const _key = 'garage';
  static const _selectedKey = 'garage_selected';

  @override
  GarageState build() {
    // The sample account comes with a Hilux, like Ahmed in the acceptance journey.
    ref.listen(sessionProvider, (prev, next) {
      if (next.signedIn && !(prev?.signedIn ?? false) && state.vehicles.isEmpty) {
        add('v-hilux-16p');
      }
    });
    final prefs = ref.watch(sharedPreferencesProvider);
    final vehicles = [
      for (final row in prefs.getStringList(_key) ?? const <String>[])
        if (row.split('|') case [final id, final variantId])
          GarageVehicle(id: id, variantId: variantId),
    ];
    return GarageState(vehicles: vehicles, selectedId: prefs.getString(_selectedKey));
  }

  Future<void> add(String variantId) async {
    final existing = state.vehicles.where((v) => v.variantId == variantId).firstOrNull;
    final vehicle =
        existing ??
        GarageVehicle(id: 'gv-${DateTime.now().microsecondsSinceEpoch}', variantId: variantId);
    state = GarageState(
      vehicles: existing == null ? [...state.vehicles, vehicle] : state.vehicles,
      selectedId: vehicle.id,
    );
    await _persist();
  }

  Future<void> select(String id) async {
    state = GarageState(vehicles: state.vehicles, selectedId: id);
    await _persist();
  }

  Future<void> remove(String id) async {
    final rest = state.vehicles.where((v) => v.id != id).toList();
    state = GarageState(
      vehicles: rest,
      selectedId: state.selectedId == id ? rest.firstOrNull?.id : state.selectedId,
    );
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_key, [for (final v in state.vehicles) '${v.id}|${v.variantId}']);
    final selected = state.selected?.id;
    if (selected == null) {
      await prefs.remove(_selectedKey);
    } else {
      await prefs.setString(_selectedKey, selected);
    }
  }
}

final garageProvider = NotifierProvider<GarageController, GarageState>(GarageController.new);

/// The variant all searches and fit badges use; null when no car is saved.
final selectedVariantProvider = Provider<String?>(
  (ref) => ref.watch(garageProvider.select((g) => g.selected?.variantId)),
);
